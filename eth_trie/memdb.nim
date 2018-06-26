import
  tables, hashes, rlp,
  eth_trie/types, nimcrypto/[hash, utils]

type
  MemDBTable = Table[Bytes, Bytes]
  MemDB* = object of RootObj
    tbl: MemDBTable

proc get*(db: MemDB, key: openarray[byte]): Bytes =
  db.tbl[@key]

proc del*(db: var MemDB, key: openarray[byte]): bool =
  let key = @key
  if db.tbl.hasKey(key):
    db.tbl.del(key)
    return true
  else:
    return false

proc contains*(db: MemDB, key: openarray[byte]): bool =
  db.tbl.hasKey(@key)

template printPair(k, v) =
  echo k.toHex, " = ", rlpFromBytes(v.toRange).inspect

proc put*(db: var MemDB, key, val: openarray[byte]): bool =
  let
    k = @key
    v = @val

  # printPair(k, v)

  db.tbl[k] = v
  return true

proc newMemDB*: ref MemDB =
  result = new(ref MemDB)
  result.tbl = initTable[Bytes, Bytes]()

proc `$`*(db: MemDB): string =
  for k, v in db.tbl:
    printPair(k, v)

proc len*(db: MemDB): int =
  db.tbl.len

#static:
#  assert MemDB is TrieDatabaseConcept

