import
  rlp, trie.constants, trie.validation, trie.exceptions, trie.utils.sha3,
  trie.utils.binaries, trie.utils.nodes

type
  Hash = string

  BinaryTrie* = object of object
    db*: void
    rootHash*: Hash

proc makeBinaryTrie*(db: Any; rootHash: Hash): BinaryTrie =
  result.db = db
  result.rootHash = rootHash

proc getImpl*(self: BinaryTrie; nodeHash: Hash; keypath: string): string =
  ##         Note: keypath should be in binary array format, i.e., encoded by encode_to_bin()
  if nodeHash == BLANKHASH:
    return nil
  (nodetype, leftChild, rightChild) = parseNode(self.db[nodeHash])
  if nodetype == LEAFTYPE:
    return rightChild
  elif nodetype == KVTYPE:
    if notkeypath:
      return None
    if keypath[0 .. ^1] == leftChild:
      return self.getImpl(rightChild, keypath[len(leftChild) ..< nil])
    else:
      return None
  elif nodetype == BRANCHTYPE:
    if notkeypath:
      return None
    if keypath[0 .. ^1] == BYTE0:
      return self.getImpl(leftChild, keypath[1 ..< nil])
    else:
      return self.getImpl(rightChild, keypath[1 ..< nil])
  
proc get*(self: BinaryTrie; key: string): string =
  ##         Fetches the value with a given keypath from the given node.
  ## 
  ##         Key will be encoded into binary array format first.
  return self.getImpl(self.rootHash, encodeToBin(key))

proc setImpl*(self: BinaryTrie; nodeHash: string; keypath: string; value: string;
            ifDeleteSubtrie: bool): string =
  ##         If if_delete_subtrie is set to True, what it will do is that it take in a keypath
  ##         and traverse til the end of keypath, then delete the whole subtrie of that node.
  ## 
  ##         Note: keypath should be in binary array format, i.e., encoded by encode_to_bin()
  if nodeHash == BLANKHASH:
    if value:
      return self.hashAndSave(encodeKvNode(keypath,
          self.hashAndSave(encodeLeafNode(value))))
    else:
      return BLANKHASH
  (nodetype, leftChild, rightChild) = parseNode(self.db[nodeHash])
  if nodetype == LEAFTYPE:
    if keypath:
      raise newException(LeafNodeOverrideError, "Existing kv pair is being effaced because it\'s key is the prefix of the new key")
    if ifDeleteSubtrie:
      return BLANKHASH
    return nil
  elif nodetype == KVTYPE:
    if notkeypath:
      if ifDeleteSubtrie:
        return BLANKHASH
      return nodeHash
    return self.setKvNode(keypath, nodeHash, nodetype, leftChild, rightChild, value,
                          ifDeleteSubtrie)
  elif nodetype == BRANCHTYPE:
    if notkeypath:
      if ifDeleteSubtrie:
        return BLANKHASH
      return nodeHash
    return self.setBranchNode(keypath, nodetype, leftChild, rightChild, value,
                              ifDeleteSubtrie)
  raise newException(Exception, "Invariant: This shouldn\'t ever happen")

proc set*(self: BinaryTrie; key: string; value: string): void =
  ##         Sets the value at the given keypath from the given node
  ## 
  ##         Key will be encoded into binary array format first.
  self.rootHash = self.setImpl(self.rootHash, encodeToBin(key), value)

proc setKvNode*(self: BinaryTrie; keypath: string; nodeHash: string;
                 nodeType: int; leftChild: string; rightChild: string;
                 value: string; ifDeleteSubtrie: bool): string =
  if ifDeleteSubtrie:
    if len(keypath) < len(leftChild) and keypath == leftChild[0 ..< len(keypath)]:
      return BLANKHASH
  if keypath[0 ..< len(leftChild)] == leftChild:
    var subnodeHash = self.setImpl(rightChild, keypath[len(leftChild) .. ^1], value,
                             ifDeleteSubtrie)
    if subnodeHash == BLANKHASH:
      return BLANKHASH
    (subnodetype, subLeftChild, subRightChild) = parseNode(self.db[subnodeHash])
    if subnodetype == KVTYPE:
      return self.hashAndSave(encodeKvNode(nil, subRightChild))
    else:
      return self.hashAndSave(encodeKvNode(leftChild, subnodeHash))
  else:
    commonPrefixLen = getCommonPrefixLength(leftChild, keypath[0 .. ^1])
    if :
      return nodeHash
    if len(keypath) == commonPrefixLen + 1:
      valnode = self.hashAndSave(encodeLeafNode(value))
    else:
      valnode = self.hashAndSave(encodeKvNode(
          keypath[commonPrefixLen + 1 ..< nil],
          self.hashAndSave(encodeLeafNode(value))))
    if len(leftChild) == commonPrefixLen + 1:
      oldnode = rightChild
    else:
      oldnode = self.hashAndSave(encodeKvNode(
          leftChild[commonPrefixLen + 1 ..< nil], rightChild))
    if keypath[commonPrefixLen ..< commonPrefixLen + 1] == BYTE1:
      newsub = self.hashAndSave(encodeBranchNode(oldnode, valnode))
    else:
      newsub = self.hashAndSave(encodeBranchNode(valnode, oldnode))
    if commonPrefixLen:
      return self.hashAndSave(encodeKvNode(leftChild[0 .. ^1], newsub))
    else:
      return newsub
  
proc setBranchNode*(self: BinaryTrie; keypath: string; nodeType: int;
                      leftChild: string; rightChild: string; value: string;
                      ifDeleteSubtrie: bool): string =
  if keypath[0 ..< 1] == BYTE0:
    var
      newLeftChild = self.setImpl(leftChild, keypath[1 .. ^1], value, ifDeleteSubtrie)
      newRightChild = rightChild
  else:
    newRightChild = self.setImpl(rightChild, keypath[1 ..< nil], value, ifDeleteSubtrie)
    newLeftChild = leftChild
  if newLeftChild == BLANKHASH or newRightChild == BLANKHASH:
    (subnodetype, subLeftChild, subRightChild) = parseNode(self.db[nil])
    var firstBit = nil
    if subnodetype == KVTYPE:
      return self.hashAndSave(encodeKvNode(nil, subRightChild))
    elif subnodetype in (BRANCHTYPE, LEAFTYPE):
      return self.hashAndSave(encodeKvNode(firstBit, ))
  else:
    return self.hashAndSave(encodeBranchNode(newLeftChild, newRightChild))
  
proc deleteSubtrie*(self: BinaryTrie; key: string): void =
  ##         Given a key prefix, delete the whole subtrie that starts with the key prefix.
  ## 
  ##         Key will be encoded into binary array format first.
  ## 
  ##         It will call `setImpl` with `if_delete_subtrie` set to True.
  self.rootHash = self.setImpl(self.rootHash, encodeToBin(key))

proc hashAndSave*(self: BinaryTrie; node: string): string =
  ##         Saves a node into the database and returns its hash
  var nodeHash = keccak(node)
  self.db[nodeHash] = node
  return nodeHash

