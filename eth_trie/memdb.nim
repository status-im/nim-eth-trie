import
  tables, hashes, rlp/types as rlpTypes,
  eth_trie/types, nimcrypto/[hash, utils]

type
  MemDBTable = Table[KeccakHash, Bytes]
  MemDB* = object of RootObj
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

proc contains*(db: MemDB, key: KeccakHash): bool =
  db.tbl.hasKey(key)

proc toSeq(r: BytesRange): Bytes {.used.} =
  newSeq(result, r.len)
  for i in 0 ..< r.len:
    result[i] = r[i]
  shallow(result)

proc put*(db: var MemDB, key: KeccakHash, value: BytesRange): bool =
  db.tbl[key] = value.toSeq
  return true

proc put*(db: var MemDB, key: KeccakHash, value: Bytes): bool =
  db.tbl[key] = value
  return true

proc newMemDB*: ref MemDB =
  result = new(ref MemDB)
  result.tbl = initTable[KeccakHash, Bytes]()

proc `$`*(db: MemDB): string =
  for k, v in db.tbl:
    echo k, " -> ", v

proc len*(db: MemDB): int =
  db.tbl.len

static:
  assert MemDB is TrieDatabaseConcept

