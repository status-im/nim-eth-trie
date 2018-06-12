import
  nimcrypto/[keccak, hash], types, utils/binaries, nodes, rlp/types as rlpTypes, utils

export
  types, keccak, hash

type
  BinaryTrie[DB: TrieDatabase] = object
    dbLink: ref DB
    rootHash: BytesRange

  NodeOverrideError* = object of Exception

proc toBytesRange(hash: KeccakHash): BytesRange =
  result = newRange[byte](32)
  copyMem(result.baseAddr, hash.data[0].unsafeAddr, 32)

proc toHash(nodeHash: BytesRange): KeccakHash =
  assert(nodeHash.len == 32)
  copyMem(result.data[0].addr, nodeHash.baseAddr, 32)

let
  BLANK_HASH     = hashFromHex("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470").toBytesRange
  zeroBytesRange = Range[byte]()

proc initBinaryTrie*[DB](db: ref DB): BinaryTrie[DB] =
  result.dbLink = db
  result.rootHash = BLANK_HASH

template queryDB(self: BinaryTrie, nodeHash: BytesRange): BytesRange =
  self.dbLink[].get(toHash(nodeHash)).toRange

proc getAux(self: BinaryTrie, nodeHash: BytesRange, keyPath: BinVector): BytesRange =
  # Empty trie
  if nodeHash == BLANK_HASH:
    return zeroBytesRange

  let node = parseNode(self.queryDB(nodeHash))
  # Key-value node descend
  if node.kind == LEAF_TYPE:
    if keyPath.len != 0: return zeroBytesRange
    return node.rightChild
  elif node.kind == KV_TYPE:
    # keyPath too short
    if keyPath.len == 0: return zeroBytesRange
    if keyPath[0..node.leftChild.len] == node.leftChild:
      return self.getAux(node.rightChild, keyPath[node.leftChild.len.. ^1])
    else:
      return zeroBytesRange
  # Branch node descend
  elif node.kind == BRANCH_TYPE:
    # keyPath too short
    if keyPath.len == 0: return zeroBytesRange
    if keyPath[0] == binaryZero:
      return self.getAux(node.leftChild, keyPath[1..^1])
    else:
      return self.getAux(node.rightChild, keyPath[1..^1])

proc get*(self: BinaryTrie, key: BytesRange): BytesRange =
  return self.getAux(self.rootHash, encodeToBin(key).toRange)

proc hashAndSave(self: BinaryTrie, node: BytesRange|Bytes): BytesRange =
  let nodeHash = keccak256.digest(node.baseAddr, uint(node.len))
  discard self.dbLink[].put(nodeHash, node)
  result = nodeHash.toBytesRange

proc setBranchNode(self: BinaryTrie, keyPath: BinVector, node: TrieNode, value: BytesRange, deleteSubtrie = false): BytesRange
proc setKVNode(self: BinaryTrie, keyPath: BinVector, nodeHash: BytesRange, node: TrieNode, value: BytesRange, deleteSubtrie = false): BytesRange

const
  overrideErrorMsg = "Fail to set the value because the prefix of it's key is the same as existing key"

proc setAux(self: BinaryTrie, nodeHash: BytesRange, keyPath: BinVector, value: BytesRange, deleteSubtrie = false): BytesRange =
  ## If deleteSubtrie is set to True, what it will do is that it take in a keyPath
  ## and traverse til the end of keyPath, then delete the whole subtrie of that node.
  ## Note: keyPath should be in binary array format, i.e., encoded by encode_to_bin()

  # Empty trie
  if nodeHash == BLANK_HASH:
    if value.len != 0:
      let node = encodeKVNode(keyPath, self.hashAndsave(encodeLeafNode(value)))
      return self.hashAndsave(node)
    else: return BLANK_HASH

  let node = parseNode(self.queryDB(nodeHash))

  # Node is a leaf node
  if node.kind == LEAF_TYPE:
    # keyPath must match, there should be no remaining keyPath
    if keyPath.len != 0:
      raise newException(NodeOverrideError, overrideErrorMsg)
    if deleteSubtrie: return BLANK_HASH
    if value.len != 0:
      return self.hashAndsave(encodeLeafNode(value))
    else: return BLANK_HASH
  # node is a key-value node
  elif node.kind == KV_TYPE:
    # keyPath too short
    if keyPath.len == 0:
      if deleteSubtrie: return BLANK_HASH
      else:
        raise newException(NodeOverrideError, overrideErrorMsg)
    return self.setKVNode(keyPath, nodeHash, node, value, deleteSubtrie)
  # node is a branch node
  elif node.kind == BRANCH_TYPE:
    # keyPath too short
    if keyPath.len == 0:
      if deleteSubtrie: return BLANK_HASH
      else:
        raise newException(NodeOverrideError, overrideErrorMsg)
    return self.setBranchNode(keyPath, node, value, deleteSubtrie)
  raise newException(Exception, "Invariant: This shouldn't ever happen")

proc set*(self: var BinaryTrie, key, value: BytesRange) =
  ## Sets the value at the given keyPath from the given node
  ## Key will be encoded into binary array format first.

  self.rootHash = self.setAux(self.rootHash, encodeToBin(key).toRange, value)

proc setBranchNode(self: BinaryTrie, keyPath: BinVector, node: TrieNode, value: BytesRange, deleteSubtrie = false): BytesRange =
  # Which child node to update? Depends on first bit in keyPath
  var newLeftChild, newRightChild: BytesRange

  if keyPath[0] == binaryZero:
    newLeftChild  = self.setAux(node.leftChild, keyPath[1..^1], value, deleteSubtrie)
    newRightChild = node.rightChild
  else:
    newRightChild = self.setAux(node.rightChild, keyPath[1..^1], value, deleteSubtrie)
    newLeftChild  = node.leftChild

  # Compress branch node into kv node
  if newLeftChild == BLANK_HASH or newRightChild == BLANK_HASH:
    let key = if newLeftChild != BLANK_HASH: newLeftChild else: newRightChild
    let subNode = parseNode(self.queryDB(key))

    const bits = [@[binaryZero], @[binaryOne]]
    let firstBit = bits[(newRightChild != BLANK_HASH).ord].toRange

    # Compress (k1, (k2, NODE)) -> (k1 + k2, NODE)
    if subnode.kind == KV_TYPE:
      let node = encodeKVNode(firstBit & subNode.leftChild, subNode.rightChild)
      return self.hashAndSave(node)
    # kv node pointing to a branch node
    elif subnode.kind in {BRANCH_TYPE, LEAF_TYPE}:
      let childNode = if newLeftChild != BLANK_HASH: newLeftChild else: newRightChild
      let node = encodeKVNode(firstBit, childNode)
      return self.hashAndSave(node)
  else:
    return self.hashAndSave(encodeBranchNode(newLeftChild, newRightChild))

proc setKVNode(self: BinaryTrie, keyPath: BinVector, nodeHash: BytesRange, node: TrieNode, value: BytesRange, deleteSubtrie = false): BytesRange =
  # keyPath prefixes match
  if deleteSubtrie:
    if keyPath.len < node.leftChild.len and keyPath == node.leftChild[0..<keyPath.len]:
      return BLANK_HASH
  if keyPath[0..<node.leftChild.len] == node.leftChild:
    # Recurse into child
    let subnodeHash = self.setAux(node.rightChild, keyPath[node.leftChild.len..^1], value, deleteSubtrie)

    # If child is empty
    if subnodeHash == BLANK_HASH:  return BLANK_HASH
    let subNode = parseNode(self.queryDB(subnodeHash))

    # If the child is a key-value node, compress together the keyPaths
    # into one node
    if subnode.kind == KV_TYPE:
      return self.hashAndSave(encodeKVNode(node.leftChild & subNode.leftChild, subNode.rightChild))
    else:
      return self.hashAndSave(encodeKVNode(node.leftChild, subnodeHash))
  # keyPath prefixes don't match. Here we will be converting a key-value node
  # of the form (k, CHILD) into a structure of one of the following forms:
  # 1.    (k[:-1], (NEWCHILD, CHILD))
  # 2.    (k[:-1], ((k2, NEWCHILD), CHILD))
  # 3.    (k1, ((k2, CHILD), NEWCHILD))
  # 4.    (k1, ((k2, CHILD), (k2', NEWCHILD))
  # 5.    (CHILD, NEWCHILD)
  # 6.    ((k[1:], CHILD), (k', NEWCHILD))
  # 7.    ((k[1:], CHILD), NEWCHILD)
  # 8.    (CHILD, (k[1:], NEWCHILD))
  else:
    let commonPrefixLen = getCommonPrefixLength(node.leftChild, keyPath[0..<node.leftChild.len])
    # New key-value pair can not contain empty value
    # Or one can not delete non-exist subtrie
    if value.len == 0 or deleteSubtrie: return nodeHash

    var valNode, oldNode, newSub: BytesRange
    # valnode: the child node that has the new value we are adding
    # Case 1: keyPath prefixes almost match, so we are in case (1), (2), (5), (6)
    if keyPath.len == commonPrefixLen + 1:
      valNode = self.hashAndSave(encodeLeafNode(value))
    # Case 2: keyPath prefixes mismatch in the middle, so we need to break
    # the keyPath in half. We are in case (3), (4), (7), (8)
    else:
      if keyPath.len <= commonPrefixLen:
        raise newException(NodeOverrideError, overrideErrorMsg)
      let nnode = encodeKVNode(keyPath[commonPrefixLen + 1..^1], self.hashAndSave(encodeLeafNode(value)))
      valNode = self.hashAndSave(nnode)

    # oldnode: the child node the has the old child value
    # Case 1: (1), (3), (5), (6)
    if node.leftChild.len == commonPrefixLen + 1:
      oldNode = node.rightChild
    # (2), (4), (6), (8)
    else:
      oldNode = self.hashAndSave(encodeKVNode(node.leftChild[commonPrefixLen + 1..^1], node.rightChild))

    # Create the new branch node (because the key paths diverge, there has to
    # be some "first bit" at which they diverge, so there must be a branch
    # node somewhere)
    if keyPath[commonPrefixLen] == binaryOne:
      newSub = self.hashAndSave(encodeBranchNode(oldNode, valNode))
    else:
      newSub = self.hashAndSave(encodeBranchNode(valNode, oldNode))

    # Case 1: keyPath prefixes match in the first bit, so we still need
    # a kv node at the top
    # (1) (2) (3) (4)
    if commonPrefixLen != 0:
      return self.hashAndSave(encodeKVNode(node.leftChild[0..<commonPrefixLen], newSub))
    # Case 2: keyPath prefixes diverge in the first bit, so we replace the
    # kv node with a branch node
    # (5) (6) (7) (8)
    else:
      return newSub

proc exists*(self: BinaryTrie, key: BytesRange): bool =
  self.get(key) != zeroBytesRange

proc delete*(self: BinaryTrie, key: BytesRange) =
  ## Equals to setting the value to zeroBytesRange

  self.rootHash = self.setAux(self.rootHash, encodeToBin(key), zeroBytesRange)

proc deleteSubtrie*(self: BinaryTrie, key: BytesRange) =
  ## Given a key prefix, delete the whole subtrie that starts with the key prefix.
  ## Key will be encoded into binary array format first.
  ## It will call `_set` with `if_delete_subtrie` set to True.

  self.rootHash = self.setAux(self.rootHash, encodeToBin(key), zeroBytesRange, true)

# Convenience
proc rootNode*(self: BinaryTrie): BytesRange =
  self.queryDB(self.rootHash)

proc rootNode*(self: BinaryTrie, node: BytesRange) =
  self.rootHash = self.hashAndSave(node)

# Dictionary API
proc `[]`*(self: BinaryTrie, key: BytesRange): BytesRange =
  self.get(key)

proc `[]=`*(self: BinaryTrie, key, value: BytesRange) =
  self.set(key, value)

proc contains*(self: BinaryTrie, key: BytesRange): bool =
  self.exists(key)
