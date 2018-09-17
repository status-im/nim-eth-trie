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
  copyMem(result[ 0].addr, a[0].unsafeAddr, 32)
  copyMem(result[32].addr, b[0].unsafeAddr, 32)

proc initDoubleHash(x: KeccakHash): DoubleHash =
  initDoubleHash(x.data, x.data)

proc init*(x: typedesc[SparseMerkleTrie], db: DB): SparseMerkleTrie =
  result.db = db
  # Initialize an empty tree with one branch
  var value = initDoubleHash(emptyNodeHashes[0])
  result.rootHash = keccakHash(value).toRange
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

proc get*(self: SparseMerkleTrie, key: BytesContainer): BytesRange =
  assert(key.len == 20)
  let path = MutByteRange(key.toRange).bits
  var nodeHash = self.rootHash
  for targetBit in path:
    let value = self.db.get(nodeHash.toOpenArray).toRange
    if targetBit: nodeHash = value[32..^1]
    else: nodeHash = value[0..31]

  if nodeHash == emptyLeafNodeHash:
    result = zeroBytesRange
  else:
    result = self.db.get(nodeHash.toOpenArray).toRange

proc hashAndSave*(self: SparseMerkleTrie, node: BytesRange): BytesRange =
  result = keccakHash(node)
  self.db.put(result.toOpenArray, node.toOpenArray)

proc hashAndSave*(self: SparseMerkleTrie, a, b: BytesRange): BytesRange =
  let value = initDoubleHash(a.toOpenArray, b.toOpenArray)
  result = keccakHash(value).toRange
  self.db.put(result.toOpenArray, value)

proc setAux(self: var SparseMerkleTrie, value: BytesRange,
    path: BitRange, depth: int, nodeHash: BytesRange): BytesRange =
  if depth == treeHeight:
    result = self.hashAndSave(value)
  else:
    let node = self.db.get(nodeHash.toOpenArray).toRange
    if path[depth]:
      result = self.hashAndSave(node[0..32], self.setAux(value, path, depth+1, node[32..^1]))
    else:
      result = self.hashAndSave(self.setAux(value, path, depth+1, node[0..31]), node[32..^1])

proc set*(self: var SparseMerkleTrie, key, value: distinct BytesContainer) =
  assert(key.len == 20)
  let path = MutByteRange(key.toRange).bits
  self.rootHash = self.setAux(value.toRange, path, 0, self.rootHash)

template exists*(self: SparseMerkleTrie, key: BytesContainer): bool =
  self.get(toRange(key)) != zeroBytesRange

proc delete*(self: var SparseMerkleTrie, key: BytesContainer) =
  ## Equals to setting the value to zeroBytesRange
  assert(key.len == 20)
  self.set(key, zeroBytesRange)

# Dictionary API
template `[]`*(self: SparseMerkleTrie, key: BytesContainer): BytesRange =
  self.get(key)

template `[]=`*(self: var SparseMerkleTrie, key, value: distinct BytesContainer) =
  self.set(key, value)

template contains*(self: SparseMerkleTrie, key: BytesContainer): bool =
  self.exists(key)
