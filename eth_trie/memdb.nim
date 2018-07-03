import
  tables, hashes, rlp,
  eth_trie/types, nimcrypto/[hash, utils, keccak]

type
  MemDBTable = Table[Bytes, Bytes]
  MemDB* = object of RootObj
    tbl: MemDBTable

proc get*(db: MemDB, key: openarray[byte]): Bytes =
  db.tbl[@key]

proc del*(db: var MemDB, key: openarray[byte]) =
  db.tbl.del(@key)

proc contains*(db: MemDB, key: openarray[byte]): bool =
  db.tbl.hasKey(@key)

template printPair(k, v) =
  echo k.toHex, " = ", rlpFromBytes(v.toRange).inspect

proc put*(db: var MemDB, key, val: openarray[byte]) =
  let
    k = @key
    v = @val

  # printPair(k, v)

  db.tbl[k] = v

proc keccak*(r: BytesRange): KeccakHash =
  keccak256.digest r.toOpenArray

let
  # XXX: turning this into a constant leads to a compilation failure
  emptyRlp = rlp.encode ""
  emptyRlpHash = emptyRlp.keccak

proc newMemDB*: ref MemDB =
  result = new(ref MemDB)
  result.tbl = initTable[Bytes, Bytes]()
  put(result[], emptyRlpHash.data, emptyRlp.toOpenArray)

proc `$`*(db: MemDB): string =
  for k, v in db.tbl:
    printPair(k, v)

proc len*(db: MemDB): int =
  db.tbl.len

#static:
#  assert MemDB is TrieDatabaseConcept

