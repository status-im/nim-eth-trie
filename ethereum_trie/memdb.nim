import
  tables, hashes, rlp/types as rlpTypes,
  ethereum_trie/types

type
  MemDBTable = Table[KeccakHash, Bytes]
  MemDB* = object
    tbl: MemDBTable

proc hash*(key: KeccakHash): int =
  hashes.hash(key.data)

proc get*(db: MemDB, key: KeccakHash): Bytes =
  db.tbl[key]

proc del*(db: var MemDB, key: KeccakHash): bool =
  if db.tbl.hasKey(key):
    db.tbl.del(key)
    return true
  else:
    return false

proc toSeq(r: BytesRange): Bytes =
  newSeq(result, r.len)
  for i in 0 ..< r.len:
    result[i] = r[i]
  shallow(result)

proc put*(db: var MemDB, key: KeccakHash, value: BytesRange): bool =
  db.tbl[key] = value.toSeq
  return true

proc newMemDB*: ref MemDB =
  result.tbl = initTable[KeccakHash, Bytes]()

static:
  assert MemDB is TrieDatabase

