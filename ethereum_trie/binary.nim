import
  nimcrypto/[keccak, hash], types, utils/binaries, nodes,
  rlp/types as rlpTypes, utils, ranges/ptr_arith

export
  types, keccak, hash, rlpTypes

type
  BinaryTrie*[DB: TrieDatabase] = object
    dbLink: ref DB
    rootHash: TrieNodeKey

  NodeOverrideError* = object of Exception

  BytesContainer* = BytesRange | Bytes | string

proc toTrieNodeKey*(hash: KeccakHash): TrieNodeKey =
  result = newRange[byte](32)
  copyMem(result.baseAddr, hash.data.baseAddr, 32)

proc toHash*(nodeHash: TrieNodeKey): KeccakHash =
  assert(nodeHash.len == 32)
  copyMem(result.data.baseAddr, nodeHash.baseAddr, 32)

template toRange*(hash: KeccakHash): BytesRange =
  toTrieNodeKey(hash)

let
  BLANK_HASH*     = hashFromHex("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470").toTrieNodeKey
  zeroBytesRange* = Range[byte]()

proc init*[DB](x: typedesc[BinaryTrie[DB]], db: ref DB, rootHash = BLANK_HASH): BinaryTrie[DB] =
  result.dbLink = db
  result.rootHash = rootHash

proc initBinaryTrie*[DB](db: ref DB, rootHash = BLANK_HASH): BinaryTrie[DB] =
  init(BinaryTrie[DB], db, rootHash)

proc getRootHash*(self: BinaryTrie): TrieNodeKey {.inline.} =
  self.rootHash

proc getDB*[DB](self: BinaryTrie[DB]): ref DB {.inline.} =
  self.dbLink

template queryDB(self: BinaryTrie, nodeHash: TrieNodeKey): BytesRange =
  self.dbLink[].get(toHash(nodeHash)).toRange

proc getAux(self: BinaryTrie, nodeHash: TrieNodeKey, keyPath: TrieBitVector): BytesRange =
  # Empty trie
  if nodeHash == BLANK_HASH:
    return zeroBytesRange

  let node = parseNode(self.queryDB(nodeHash))

  # Key-value node descend
  if node.kind == LEAF_TYPE:
    if keyPath.len != 0: return zeroBytesRange
    return node.value
  elif node.kind == KV_TYPE:
    # keyPath too short
    if keyPath.len == 0: return zeroBytesRange
    let sliceLen = min(node.keyPath.len, keyPath.len)
    if keyPath[0..<sliceLen] == node.keyPath:
      return self.getAux(node.child, keyPath.sliceToEnd(node.keyPath.len))
    else:
      return zeroBytesRange
  # Branch node descend
  elif node.kind == BRANCH_TYPE:
    # keyPath too short
    if keyPath.len == 0: return zeroBytesRange
    if keyPath[0] == binaryZero:
      return self.getAux(node.leftChild, keyPath.sliceToEnd(1))
    else:
      return self.getAux(node.rightChild, keyPath.sliceToEnd(1))

proc get*(self: BinaryTrie, key: BytesContainer): BytesRange {.inline.} =
  return self.getAux(self.rootHash, encodeToBin(toRange(key)))

proc hashAndSave(self: BinaryTrie, node: BytesRange | Bytes): TrieNodeKey =
  let nodeHash = keccak256.digest(node.baseAddr, uint(node.len))
  discard self.dbLink[].put(nodeHash, node)
  result = toTrieNodeKey(nodeHash)

proc setBranchNode(self: BinaryTrie, keyPath: TrieBitVector, node: TrieNode,
  value: BytesRange, deleteSubtrie = false): TrieNodeKey
proc setKVNode(self: BinaryTrie, keyPath: TrieBitVector, nodeHash: TrieNodeKey,
  node: TrieNode, value: BytesRange, deleteSubtrie = false): TrieNodeKey

const
  overrideErrorMsg = "Fail to set the value because the prefix of it's key is the same as existing key"

proc setAux(self: BinaryTrie, nodeHash: TrieNodeKey, keyPath: TrieBitVector,
  value: BytesRange, deleteSubtrie = false): TrieNodeKey =
  ## If deleteSubtrie is set to True, what it will do is that it take in a keyPath
  ## and traverse til the end of keyPath, then delete the whole subtrie of that node.
  ## Note: keyPath should be in binary array format, i.e., encoded by encode_to_bin()

  # Empty trie
  if nodeHash == BLANK_HASH:
    if value.len != 0:
      let node = encodeKVNode(keyPath, self.hashAndsave(encodeLeafNode(value)))
      return self.hashAndsave(node)
    else:
      return BLANK_HASH

  let node = parseNode(self.queryDB(nodeHash))

  # Node is a leaf node
  if node.kind == LEAF_TYPE:
    # keyPath must match, there should be no remaining keyPath
    if keyPath.len != 0:
      raise newException(NodeOverrideError, overrideErrorMsg)
    if deleteSubtrie: return BLANK_HASH

    if value.len != 0:
      return self.hashAndsave(encodeLeafNode(value))
    else:
      return BLANK_HASH
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

# beware of Nim's bug #8059, generic typeclass param
proc set*(self: var BinaryTrie, key, value: BytesContainer) {.inline.} =
  ## Sets the value at the given keyPath from the given node
  ## Key will be encoded into binary array format first.

  self.rootHash = self.setAux(self.rootHash, encodeToBin(toRange(key)), toRange(value))

proc setBranchNode(self: BinaryTrie, keyPath: TrieBitVector, node: TrieNode,
  value: BytesRange, deleteSubtrie = false): TrieNodeKey =
  # Which child node to update? Depends on first bit in keyPath
  var newLeftChild, newRightChild: TrieNodeKey

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
    let firstBit = bits[(newRightChild != BLANK_HASH).ord]

    # Compress (k1, (k2, NODE)) -> (k1 + k2, NODE)
    if subNode.kind == KV_TYPE:
      let node = encodeKVNode(concat(firstBit, subNode.keyPath), subNode.child)
      result = self.hashAndSave(node)
    # kv node pointing to a branch node
    elif subNode.kind in {BRANCH_TYPE, LEAF_TYPE}:
      let childNode = if newLeftChild != BLANK_HASH: newLeftChild else: newRightChild
      let node = encodeKVNode(firstBit, childNode)
      result = self.hashAndSave(node)
  else:
    result = self.hashAndSave(encodeBranchNode(newLeftChild, newRightChild))

proc setKVNode(self: BinaryTrie, keyPath: TrieBitVector, nodeHash: TrieNodeKey,
  node: TrieNode, value: BytesRange, deleteSubtrie = false): TrieNodeKey =
  # keyPath prefixes match
  if deleteSubtrie:
    if keyPath.len < node.keyPath.len and keyPath == node.keyPath[0..<keyPath.len]:
      return BLANK_HASH

  let sliceLen = min(node.keyPath.len, keyPath.len)

  if keyPath[0..<sliceLen] == node.keyPath:
    # Recurse into child
    let subNodeHash = self.setAux(node.child, keyPath.sliceToEnd(node.keyPath.len), value, deleteSubtrie)

    # If child is empty
    if subNodeHash == BLANK_HASH:
      return BLANK_HASH
    let subNode = parseNode(self.queryDB(subNodeHash))

    # If the child is a key-value node, compress together the keyPaths
    # into one node
    if subNode.kind == KV_TYPE:
      return self.hashAndSave(encodeKVNode(node.keyPath & subNode.keyPath, subNode.child))
    else:
      return self.hashAndSave(encodeKVNode(node.keyPath, subNodeHash))
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
    let commonPrefixLen = getCommonPrefixLength(node.keyPath, keyPath[0..<sliceLen])
    # New key-value pair can not contain empty value
    # Or one can not delete non-exist subtrie
    if value.len == 0 or deleteSubtrie: return nodeHash

    var valNode, oldNode, newSub: TrieNodeKey
    # valnode: the child node that has the new value we are adding
    # Case 1: keyPath prefixes almost match, so we are in case (1), (2), (5), (6)
    if keyPath.len == commonPrefixLen + 1:
      valNode = self.hashAndSave(encodeLeafNode(value))
    # Case 2: keyPath prefixes mismatch in the middle, so we need to break
    # the keyPath in half. We are in case (3), (4), (7), (8)
    else:
      if keyPath.len <= commonPrefixLen:
        raise newException(NodeOverrideError, overrideErrorMsg)
      let nnode = encodeKVNode(keyPath[(commonPrefixLen + 1)..^1], self.hashAndSave(encodeLeafNode(value)))
      valNode = self.hashAndSave(nnode)

    # oldnode: the child node the has the old child value
    # Case 1: (1), (3), (5), (6)
    if node.keyPath.len == commonPrefixLen + 1:
      oldNode = node.child
    # (2), (4), (6), (8)
    else:
      oldNode = self.hashAndSave(encodeKVNode(node.keyPath[(commonPrefixLen + 1)..^1], node.child))

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
      return self.hashAndSave(encodeKVNode(node.keyPath[0..<commonPrefixLen], newSub))
    # Case 2: keyPath prefixes diverge in the first bit, so we replace the
    # kv node with a branch node
    # (5) (6) (7) (8)
    else:
      return newSub

template exists*(self: BinaryTrie, key: BytesContainer): bool =
  self.get(toRange(key)) != zeroBytesRange

proc delete*(self: var BinaryTrie, key: BytesContainer) {.inline.} =
  ## Equals to setting the value to zeroBytesRange

  self.rootHash = self.setAux(self.rootHash, encodeToBin(toRange(key)), zeroBytesRange)

proc deleteSubtrie*(self: var BinaryTrie, key: BytesContainer) {.inline.} =
  ## Given a key prefix, delete the whole subtrie that starts with the key prefix.
  ## Key will be encoded into binary array format first.
  ## It will call `_set` with `if_delete_subtrie` set to True.

  self.rootHash = self.setAux(self.rootHash, encodeToBin(toRange(key)), zeroBytesRange, true)

# Convenience
proc rootNode*(self: BinaryTrie): BytesRange {.inline.} =
  self.queryDB(self.rootHash)

proc rootNode*(self: var BinaryTrie, node: BytesContainer) {.inline.} =
  self.rootHash = self.hashAndSave(toRange(node))

# Dictionary API
template `[]`*(self: BinaryTrie, key: BytesContainer): BytesRange =
  self.get(key)

# beware of Nim's bug #8059, generic typeclass param
template `[]=`*(self: var BinaryTrie, key, value: BytesContainer) =
  self.set(key, value)

template contains*(self: BinaryTrie, key: BytesContainer): bool =
  self.exists(key)
