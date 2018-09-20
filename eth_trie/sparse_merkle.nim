import
  ranges/[ptr_arith, typedranges, bitranges],
  rlp/types as rlpTypes,
  types, constants, utils

export
  types, rlpTypes, utils, bitranges

type
  DB = TrieDatabaseRef

  SparseMerkleTrie* = object
    db: DB
    rootHash: BytesRange

const
  treeHeight = 160
  pathLen = treeHeight div 8
  emptyLeafNodeHash = blankStringHash

proc makeInitialEmptyTreeHash(H: static[int]): array[H, KeccakHash] =
  result[^1] = emptyLeafNodeHash
  for i in countdown(H-1, 1):
    result[i - 1] = keccakHash(result[i], result[i])

# cannot yet turn this into compile time constant
let emptyNodeHashes* = makeInitialEmptyTreeHash(treeHeight)

proc `==`(a: BytesRange, b: KeccakHash): bool =
  if a.len != b.data.len: return false
  equalMem(a.baseAddr, b.data[0].unsafeAddr, a.len)

type
  # 256 * 2 div 8
  DoubleHash = array[64, byte]

proc initDoubleHash(a, b: openArray[byte]): DoubleHash =
  assert(a.len == 32, $a.len)
  assert(b.len == 32, $b.len)
  copyMem(result[ 0].addr, a[0].unsafeAddr, 32)
  copyMem(result[32].addr, b[0].unsafeAddr, 32)

proc initDoubleHash(x: KeccakHash): DoubleHash =
  initDoubleHash(x.data, x.data)

proc init*(x: typedesc[SparseMerkleTrie], db: DB): SparseMerkleTrie =
  result.db = db
  # Initialize an empty tree with one branch
  var value = initDoubleHash(emptyNodeHashes[0])
  result.rootHash = keccakHash(value)
  result.db.put(result.rootHash.toOpenArray, value)

  for i in 0..<treeHeight - 1:
    value = initDoubleHash(emptyNodeHashes[i+1])
    result.db.put(emptyNodeHashes[i].data, value)

  result.db.put(emptyLeafNodeHash.data, zeroBytesRange.toOpenArray)

proc initSparseMerkleTrie*(db: DB): SparseMerkleTrie =
  init(SparseMerkleTrie, db)

proc getDB*(t: SparseMerkleTrie): auto = t.db

proc getRootHash*(self: SparseMerkleTrie): BytesRange {.inline.} =
  self.rootHash

proc getAux(self: SparseMerkleTrie, path: BitRange, rootHash: BytesRange): BytesRange =
  var nodeHash = rootHash
  for targetBit in path:
    let value = self.db.get(nodeHash.toOpenArray).toRange
    if value.len == 0: return zeroBytesRange
    if targetBit: nodeHash = value[32..^1]
    else: nodeHash = value[0..31]

  if nodeHash == emptyLeafNodeHash:
    result = zeroBytesRange
  else:
    result = self.db.get(nodeHash.toOpenArray).toRange

# Get gets a key from the tree.
proc get*(self: SparseMerkleTrie, key: BytesContainer): BytesRange =
  assert(key.len == pathLen)
  let path = MutByteRange(key.toRange).bits
  self.getAux(path, self.rootHash)

# GetForRoot gets a key from the tree at a specific root.
proc get*(self: SparseMerkleTrie, key, rootHash: distinct BytesContainer): BytesRange =
  assert(key.len == pathLen)
  let path = MutByteRange(key.toRange).bits
  self.getAux(path, rootHash.toRange)

proc hashAndSave*(self: SparseMerkleTrie, node: BytesRange): BytesRange =
  result = keccakHash(node)
  self.db.put(result.toOpenArray, node.toOpenArray)

proc hashAndSave*(self: SparseMerkleTrie, a, b: BytesRange): BytesRange =
  let value = initDoubleHash(a.toOpenArray, b.toOpenArray)
  result = keccakHash(value)
  self.db.put(result.toOpenArray, value)

proc setAux(self: var SparseMerkleTrie, value: BytesRange,
    path: BitRange, depth: int, nodeHash: BytesRange): BytesRange =
  if depth == treeHeight:
    result = self.hashAndSave(value)
  else:
    let
      node = self.db.get(nodeHash.toOpenArray).toRange
      leftNode = node[0..31]
      rightNode = node[32..^1]
    if path[depth]:
      result = self.hashAndSave(leftNode, self.setAux(value, path, depth+1, rightNode))
    else:
      result = self.hashAndSave(self.setAux(value, path, depth+1, leftNode), rightNode)

# sets a new value for a key in the tree, returns the new root, and sets the new current root of the tree.
proc set*(self: var SparseMerkleTrie, key, value: distinct BytesContainer) =
  assert(key.len == pathLen)
  let path = MutByteRange(key.toRange).bits
  self.rootHash = self.setAux(value.toRange, path, 0, self.rootHash)

# setForRoot sets a new value for a key in the tree at a specific root, and returns the new root.
proc set*(self: var SparseMerkleTrie, key, value, rootHash: distinct BytesContainer): BytesRange =
  assert(key.len == pathLen)
  let path = MutByteRange(key.toRange).bits
  self.setAux(value.toRange, path, 0, rootHash.toRange)

template exists*(self: SparseMerkleTrie, key: BytesContainer): bool =
  self.get(toRange(key)) != zeroBytesRange

proc delete*(self: var SparseMerkleTrie, key: BytesContainer) =
  ## Equals to setting the value to zeroBytesRange
  assert(key.len == pathLen)
  self.set(key, zeroBytesRange)

# Dictionary API
template `[]`*(self: SparseMerkleTrie, key: BytesContainer): BytesRange =
  self.get(key)

template `[]=`*(self: var SparseMerkleTrie, key, value: distinct BytesContainer) =
  self.set(key, value)

template contains*(self: SparseMerkleTrie, key: BytesContainer): bool =
  self.exists(key)

proc proveAux(self: SparseMerkleTrie, key, rootHash: BytesRange, output: var seq[BytesRange]): bool =
  assert(key.len == pathLen)
  var currVal = self.db.get(rootHash.toOpenArray).toRange
  if currVal.len == 0: return false

  let path = MutByteRange(key).bits
  for i, bit in path:
    if bit:
      # right side
      output[i] = currVal[32..^1]
      currVal = self.db.get(currVal[0..31].toOpenArray).toRange
      if currVal.len == 0: return false
    else:
      output[i] = currVal[0..31]
      currVal = self.db.get(currVal[32..^1].toOpenArray).toRange
      if currVal.len == 0: return false

# prove generates a Merkle proof for a key.
proc prove*(self: SparseMerkleTrie, key: BytesContainer): seq[BytesRange] =
  result = newSeq[BytesRange](treeHeight)
  if not self.proveAux(key.toRange, self.rootHash, result):
    result = @[]

# prove generates a Merkle proof for a key, at a specific root.
proc prove*(self: SparseMerkleTrie, key, rootHash: distinct BytesContainer): seq[BytesRange] =
  result = newSeq[BytesRange](treeHeight)
  if not self.proveAux(key.toRange, rootHash.toRange, result):
    result = @[]

# proveCompact generates a compacted Merkle proof for a key.
proc proveCompact*(self: SparseMerkleTrie, key: BytesContainer): seq[BytesRange] =
  var temp = self.prove(key)

# proveCompact generates a compacted Merkle proof for a key, at a specific root.
proc proveCompact*(self: SparseMerkleTrie, key, rootHash: distinct BytesContainer): seq[BytesRange] =
  var temp = self.prove(key, rootHash)

