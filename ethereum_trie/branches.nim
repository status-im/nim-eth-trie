import
  binary, bitvector, binaries, rlp/types,
  nimcrypto/[keccak, hash], memdb

type
  InvalidKeyError* = object of Exception

template query[DB](db: ref DB, nodeHash: TrieNodeKey): BytesRange =
  db[].get(toHash(nodeHash)).toRange

proc checkIfBranchExistImpl[DB](db: ref DB; nodeHash: TrieNodeKey; keyPrefix: TrieBitVector): bool =
  if nodeHash == BLANK_HASH:
    return false

  let node = parseNode(db.query(nodeHash))

  case node.kind:
  of LEAF_TYPE:
    if keyPrefix.len != 0: return false
    return true
  of KV_TYPE:
    if keyPrefix.len == 0: return true
    if keyPrefix.len < node.keyPath.len:
      if keyPrefix == node.keyPath[0..<keyPrefix.len]: return true
      return false
    else:
      if keyPrefix[0..<node.keyPath.len] == node.keyPath:
        return checkIfBranchExistImpl(db, node.child, keyPrefix.sliceToEnd(node.keyPath.len))
      return false
  of BRANCH_TYPE:
    if keyPrefix.len == 0: return true
    if keyPrefix[0] == binaryZero:
      return checkIfBranchExistImpl(db, node.leftChild, keyPrefix.sliceToEnd(1))
    else:
      return checkIfBranchExistImpl(db, node.rightChild, keyPrefix.sliceToEnd(1))
  else:
    raise newException(Exception, "Invariant: unreachable code path")

proc checkIfBranchExist*[DB](db: ref DB; rootHash: BytesContainer | KeccakHash, keyPrefix: BytesContainer): bool =
  ## Given a key prefix, return whether this prefix is
  ## the prefix of an existing key in the trie.
  when rootHash.type isnot KeccakHash:
    assert(rootHash.len == 32)
  checkIfBranchExistImpl(db, toRange(rootHash), encodeToBin(toRange(keyPrefix)))

proc getBranchImpl[DB](db: ref DB; nodeHash: TrieNodeKey, keyPath: TrieBitVector, output: var seq[BytesRange]) =
  if nodeHash == BLANK_HASH: return

  let nodeVal = db.query(nodeHash)
  let node = parseNode(nodeVal)

  case node.kind
  of LEAF_TYPE:
    if keyPath.len == 0:
      output.add nodeVal
    else:
      raise newException(InvalidKeyError, "Key too long")

  of KV_TYPE:
    if keyPath.len == 0:
      raise newException(InvalidKeyError, "Key too short")

    output.add nodeVal
    let sliceLen = min(keyPath.len, node.keyPath.len)
    if keyPath[0..<sliceLen] == node.keyPath:
      getBranchImpl(db, node.child, keyPath.sliceToEnd(sliceLen), output)

  of BRANCH_TYPE:
    if keyPath.len == 0:
      raise newException(InvalidKeyError, "Key too short")

    output.add nodeVal
    if keyPath[0] == binaryZero:
      getBranchImpl(db, node.leftChild, keyPath.sliceToEnd(1), output)
    else:
      getBranchImpl(db, node.rightChild, keyPath.sliceToEnd(1), output)

  else:
    raise newException(Exception, "Invariant: unreachable code path")

proc getBranch*[DB](db: ref DB; rootHash: BytesContainer | KeccakHash; key: BytesContainer): seq[BytesRange] =
  ##     Get a long-format Merkle branch
  when rootHash.type isnot KeccakHash:
    assert(rootHash.len == 32)
  result = @[]
  getBranchImpl(db, toRange(rootHash), encodeToBin(toRange(key)), result)

proc isValidBranch*(branch: seq[BytesRange], rootHash: BytesContainer | KeccakHash, key, value: BytesContainer): bool =
  when rootHash.type isnot KeccakHash:
    assert(rootHash.len == 32)

  # branch must not be empty
  assert(branch.len != 0)

  var db = newMemDB()
  for node in branch:
    assert(node.len != 0)
    let nodeHash = keccak256.digest(node.baseAddr, uint(node.len))
    discard db[].put(nodeHash, node)

  var trie = initBinaryTrie(db, rootHash)
  result = trie.get(key) == toRange(value)

proc getTrieNodesImpl[DB](db: ref DB; nodeHash: TrieNodeKey, output: var seq[BytesRange]): bool =
  ## Get full trie of a given root node

  var nodeVal: BytesRange
  if toHash(nodeHash) in db[]:
    nodeVal = db.query(nodeHash)
  else:
    return false

  let node = parseNode(nodeVal)

  case node.kind
  of KV_TYPE:
    output.add nodeVal
    result = getTrieNodesImpl(db, node.child, output)
  of BRANCH_TYPE:
    output.add nodeVal
    result = getTrieNodesImpl(db, node.leftChild, output)
    result = getTrieNodesImpl(db, node.rightChild, output)
  of LEAF_TYPE:
    output.add nodeVal
  else:
    raise newException(Exception, "Invariant: unreachable code path")

proc getTrieNodes*[DB](db: ref DB; nodeHash: BytesContainer | KeccakHash): seq[BytesRange] =
  when nodeHash.type isnot KeccakHash:
    assert(nodeHash.len == 32)
  result = @[]
  discard getTrieNodesImpl(db, toRange(nodeHash), result)

proc getWitnessImpl*[DB](db: ref DB; nodeHash: TrieNodeKey; keyPath: TrieBitVector; output: var seq[BytesRange]) =
  if keyPath.len == 0:
    if not getTrieNodesImpl(db, nodeHash, output): return

  var nodeVal: BytesRange
  if toHash(nodeHash) in db[]:
    nodeVal = db.query(nodeHash)
  else:
    return

  let node = parseNode(nodeVal)

  case node.kind
  of LEAF_TYPE:
    if keyPath.len != 0:
      raise newException(InvalidKeyError, "Key too long")
  of KV_TYPE:
    output.add nodeVal
    if keyPath.len < node.keyPath.len and node.keyPath[0..<keyPath.len] == keypath:
      if not getTrieNodesImpl(db, node.child, output): return
    elif keyPath[0..<node.keyPath.len] == node.keyPath:
      getWitnessImpl(db, node.child, keyPath.sliceToEnd(node.keyPath.len), output)
  of BRANCH_TYPE:
    output.add nodeVal
    if keyPath[0] == binaryZero:
      getWitnessImpl(db, node.leftChild, keyPath.sliceToEnd(1), output)
    else:
      getWitnessImpl(db, node.rightChild, keyPath.sliceToEnd(1), output)
  else:
    raise newException(Exception, "Invariant: unreachable code path")

proc getWitness*[DB](db: ref DB; nodeHash: BytesContainer | KeccakHash; key: BytesContainer): seq[BytesRange] =
  ##  Get all witness given a keyPath prefix.
  ##  Include
  ##
  ##  1. witness along the keyPath and
  ##  2. witness in the subtrie of the last node in keyPath
  when nodeHash.type isnot KeccakHash:
    assert(nodeHash.len == 32)
  result = @[]
  getWitnessImpl(db, toRange(nodeHash), encodeToBin(toRange(key)), result)
