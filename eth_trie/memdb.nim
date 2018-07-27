import
  tables, hashes, rlp,
  eth_trie/types, nimcrypto/[hash, utils, keccak]

type
  MemDBTable = Table[Bytes, Bytes]
  MemDB* = ref object of RootObj
    tbl: MemDBTable

proc keccak*(r: BytesRange): KeccakHash =
  keccak256.digest r.toOpenArray

let
  # XXX: turning this into a constant leads to a compilation failure
  emptyRlp = rlp.encode ""
  emptyRlpHash = emptyRlp.keccak

# XXX: This should be commited upstream
proc `==` *[T](x, y: openarray[T]): bool =
  if x.len != y.len:
    return false

  for f in low(x)..high(x):
    if x[f] != y[f]:
      return false

  result = true

proc get*(db: MemDB, key: openarray[byte]): Bytes =
  db.tbl[@key]

proc del*(db: MemDB, key: openarray[byte]) =
  # The database should ensure that the empty key is always active:
  if key != emptyRlpHash.data:
    db.tbl.del(@key)

proc contains*(db: MemDB, key: openarray[byte]): bool =
  db.tbl.hasKey(@key)

template printPair(k, v) =
  echo k.toHex, " = ", rlpFromBytes(v.toRange).inspect

proc put*(db: MemDB, key, val: openarray[byte]) =
  db.tbl[@key] = @val

proc newMemDB*: MemDB =
  result.new
  result.tbl = initTable[Bytes, Bytes]()
  put(result, emptyRlpHash.data, emptyRlp.toOpenArray)

proc `$`*(db: MemDB): string =
  for k, v in db.tbl:
    printPair(k, v)

proc len*(db: MemDB): int =
  db.tbl.len

#static:
#  assert MemDB is TrieDatabaseConcept

