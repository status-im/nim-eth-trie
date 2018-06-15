import
  binary, utils/binaries, nodes, rlp/types

template query[DB](db: ref DB, nodeHash: TrieNodeKey): BytesRange =
  db[].get(toHash(nodeHash)).toRange

proc checkIfBranchExistImpl[DB](db: ref DB; nodeHash: BytesRange; keyPrefix: BytesRange): bool =
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
        return checkIfBranchExistImpl(db, node.child, keyPrefix[node.keyPath.len..^1])
      return false
  of BRANCH_TYPE:
    if keyPrefix.len == 0: return true
    if keyPrefix[0] == binaryZero:
      return checkIfBranchExistImpl(db, node.leftChild, keyPrefix[1..^1])
    else:
      return checkIfBranchExistImpl(db, node.rightChild, keyPrefix[1..^1])
  else:
    raise newException(Exception, "Invariant: unreachable code path")

proc checkIfBranchExist*[DB](db: ref DB; rootHash: BytesRange; keyPrefix: BytesRange): bool =
  ## Given a key prefix, return whether this prefix is
  ## the prefix of an existing key in the trie.
  checkIfBranchExistImpl(db, rootHash, encodeToBin(keyPrefix).toRange)

proc getBranchImpl[DB](db: ref DB; nodeHash, keyPath: BytesRange, output: var seq[BytesRange]) =
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
    if keyPath[0..<node.keyPath.len] == node.keyPath:
      getBranchImpl(db, node.child, keyPath[node.keyPath.len..^1], output)

  of BRANCH_TYPE:
    if keyPath.len == 0:
      raise newException(InvalidKeyError, "Key too short")

    output.add nodeVal
    if keyPath[0] == binaryZero:
      getBranchImpl(db, node.leftChild, keyPath[1..^1], output)
    else:
      getBranchImpl(db, node.rightChild, keyPath[1..^1], output)

  else:
    raise newException(Exception, "Invariant: unreachable code path")

proc getBranch*[DB](db: ref DB; rootHash: BytesRange; key: BytesRange): seq[BytesRange] =
  ##     Get a long-format Merkle branch
  result = @[]
  getBranchImpl(db, rootHash, encodeToBin(key).toRange, result)


proc getTrieNodesImpl[DB](db: ref DB; nodeHash: BytesRange, output: var seq[BytesRange]) =
  ## Get full trie of a given root node

  var nodeVal: BytesRange
  if nodeHash in db[]:
    nodeVal = db.query(nodeHash)
  else:
    return

  let node = parseNode(nodeVal)

  case node.kind
  of KV_TYPE:
    output.add nodeVal
    getTrieNodesImpl(db, node.child, output)
  of BRANCH_TYPE:
    output.add nodeVal
    getTrieNodesImpl(db, node.leftChild, output)
    getTrieNodesImpl(db, node.rightChild, output)
  of LEAF_TYPE:
    output.add nodeVal
  else:
    raise Exception("Invariant: unreachable code path")

proc getTrieNodes*[DB](db: ref DB; nodeHash: BytesRange): seq[BytesRange] =
  result = @[]
  getTrieNodesImpl(db, nodeHash, result)

proc getWitnessImpl*[DB](db: ref DB; nodeHash: BytesRange; keyPath: BytesRange; output: var seq[BytesRange]) =
  proc startsWith(a, b: BytesRange): bool =
    if b.len > a.len: return false
    result = a[0..<b.len] == b
    
  if keyPath.len == 0:
    getTrieNodesImpl(db, nodeHash, output)

  var nodeVal: BytesRange
  if nodeHash in db[]:
    nodeVal = db[nodeHash]
  else:
    return

  let node = parseNode(nodeVal)

  case node.kind
  of LEAF_TYPE:
    if keyPath.len != 0:
      raise newException(InvalidKeyError, "Key too long")
  of KV_TYPE:
    if node.keyPath.startsWith(keyPath):
      output.add nodeVal
      getTrieNodesImpl(db, node.child, output)
    elif keyPath.startsWith(node.keyPath):
      output.add nodeVal
      getWitnessImpl(db, node.child, keyPath[node.keyPath.len..^1], output)
    else:
      output.add nodeVal
  of BRANCH_TYPE:
    output.add nodeVal
    if keyPath[0] == 0.char:
      getWitnessImpl(db, node.leftChild, keyPath[1..^1], output)
    else:
      getWitnessImpl(db, node.rightChild, keyPath[1..^1], output)
  else:
    raise newException(Exception, "Invariant: unreachable code path")

proc getWitness*[DB](db: ref DB; nodeHash: BytesRange; key: BytesRange): seq[BytesRange] =
  ##  Get all witness given a keyPath prefix.
  ##  Include
  ##
  ##  1. witness along the keyPath and
  ##  2. witness in the subtrie of the last node in keyPath
  result = @[]
  getWitnessImpl(db, nodeHash, encodeToBin(key).toRange, result)
