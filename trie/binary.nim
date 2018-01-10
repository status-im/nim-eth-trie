
import
  rlp, trie.constants, trie.validation, trie.exceptions, trie.utils.sha3,
  trie.utils.binaries, trie.utils.nodes

type
  BinaryTrie* = object of object
    db*: void
    rootHash*: cstring

method makeBinaryTrie*(db: Any; rootHash: void): BinaryTrie =
  result.db = db
  validateIsBytes(rootHash)
  result.rootHash = rootHash

method makeBinaryTrie*(db: Any; rootHash: void): BinaryTrie =
  result.db = db
  validateIsBytes(rootHash)
  result.rootHash = rootHash

method get*(self: BinaryTrie; key: cstring): cstring =
  ##         Fetches the value with a given keypath from the given node.
  ## 
  ##         Key will be encoded into binary array format first.
  validateIsBytes(key)
  return self._get(self.rootHash, encodeToBin(key))

method _get*(self: BinaryTrie; nodeHash: cstring; keypath: cstring): cstring =
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
      return self._get(rightChild, keypath[len(leftChild) ..< nil])
    else:
      return None
  elif nodetype == BRANCHTYPE:
    if notkeypath:
      return None
    if keypath[0 .. ^1] == BYTE0:
      return self._get(leftChild, keypath[1 ..< nil])
    else:
      return self._get(rightChild, keypath[1 ..< nil])
  
method set*(self: BinaryTrie; key: cstring; value: cstring): void =
  ##         Sets the value at the given keypath from the given node
  ## 
  ##         Key will be encoded into binary array format first.
  validateIsBytes(key)
  validateIsBytes(value)
  self.rootHash = self._set(self.rootHash, encodeToBin(key), value)

method _set*(self: BinaryTrie; nodeHash: cstring; keypath: cstring; value: cstring;
            ifDeleteSubtrie: bool): cstring =
  ##         If if_delete_subtrie is set to True, what it will do is that it take in a keypath
  ##         and traverse til the end of keypath, then delete the whole subtrie of that node.
  ## 
  ##         Note: keypath should be in binary array format, i.e., encoded by encode_to_bin()
  if nodeHash == BLANKHASH:
    if value:
      return self._hashAndSave(encodeKvNode(keypath,
          self._hashAndSave(encodeLeafNode(value))))
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
    return self._setKvNode(keypath, nodeHash, nodetype, leftChild, rightChild, value,
                          ifDeleteSubtrie)
  elif nodetype == BRANCHTYPE:
    if notkeypath:
      if ifDeleteSubtrie:
        return BLANKHASH
      return nodeHash
    return self._setBranchNode(keypath, nodetype, leftChild, rightChild, value,
                              ifDeleteSubtrie)
  raise newException(Exception, "Invariant: This shouldn\'t ever happen")

method _setKvNode*(self: BinaryTrie; keypath: cstring; nodeHash: cstring;
                  nodeType: int; leftChild: cstring; rightChild: cstring;
                  value: cstring; ifDeleteSubtrie: bool): cstring =
  if ifDeleteSubtrie:
    if len(keypath) < len(leftChild) and keypath == leftChild[0 ..< len(keypath)]:
      return BLANKHASH
  if keypath[0 ..< len(leftChild)] == leftChild:
    var subnodeHash = self._set(rightChild, keypath[len(leftChild) .. ^1], value,
                             ifDeleteSubtrie)
    if subnodeHash == BLANKHASH:
      return BLANKHASH
    (subnodetype, subLeftChild, subRightChild) = parseNode(self.db[subnodeHash])
    if subnodetype == KVTYPE:
      return self._hashAndSave(encodeKvNode(nil, subRightChild))
    else:
      return self._hashAndSave(encodeKvNode(leftChild, subnodeHash))
  else:
    commonPrefixLen = getCommonPrefixLength(leftChild, keypath[0 .. ^1])
    if :
      return nodeHash
    if len(keypath) == commonPrefixLen + 1:
      valnode = self._hashAndSave(encodeLeafNode(value))
    else:
      valnode = self._hashAndSave(encodeKvNode(
          keypath[commonPrefixLen + 1 ..< nil],
          self._hashAndSave(encodeLeafNode(value))))
    if len(leftChild) == commonPrefixLen + 1:
      oldnode = rightChild
    else:
      oldnode = self._hashAndSave(encodeKvNode(
          leftChild[commonPrefixLen + 1 ..< nil], rightChild))
    if keypath[commonPrefixLen ..< commonPrefixLen + 1] == BYTE1:
      newsub = self._hashAndSave(encodeBranchNode(oldnode, valnode))
    else:
      newsub = self._hashAndSave(encodeBranchNode(valnode, oldnode))
    if commonPrefixLen:
      return self._hashAndSave(encodeKvNode(leftChild[0 .. ^1], newsub))
    else:
      return newsub
  
method _setBranchNode*(self: BinaryTrie; keypath: cstring; nodeType: int;
                      leftChild: cstring; rightChild: cstring; value: cstring;
                      ifDeleteSubtrie: bool): cstring =
  if keypath[0 ..< 1] == BYTE0:
    var
      newLeftChild = self._set(leftChild, keypath[1 .. ^1], value, ifDeleteSubtrie)
      newRightChild = rightChild
  else:
    newRightChild = self._set(rightChild, keypath[1 ..< nil], value, ifDeleteSubtrie)
    newLeftChild = leftChild
  if newLeftChild == BLANKHASH or newRightChild == BLANKHASH:
    (subnodetype, subLeftChild, subRightChild) = parseNode(self.db[nil])
    var firstBit = nil
    if subnodetype == KVTYPE:
      return self._hashAndSave(encodeKvNode(nil, subRightChild))
    elif subnodetype in (BRANCHTYPE, LEAFTYPE):
      return self._hashAndSave(encodeKvNode(firstBit, ))
  else:
    return self._hashAndSave(encodeBranchNode(newLeftChild, newRightChild))
  
method deleteSubtrie*(self: BinaryTrie; key: cstring): void =
  ##         Given a key prefix, delete the whole subtrie that starts with the key prefix.
  ## 
  ##         Key will be encoded into binary array format first.
  ## 
  ##         It will call `_set` with `if_delete_subtrie` set to True.
  validateIsBytes(key)
  self.rootHash = self._set(self.rootHash, encodeToBin(key))

method _hashAndSave*(self: BinaryTrie; node: cstring): cstring =
  ##         Saves a node into the database and returns its hash
  validateIsBinNode(node)
  var nodeHash = keccak(node)
  self.db[nodeHash] = node
  return nodeHash

