import
  tables, hashes, rlp,
  eth_trie/types, nimcrypto/[hash, utils, keccak]

type
  MemDbRecord = object
    refCount: int
    value: Bytes

  MemDBTable = Table[Bytes, MemDbRecord]
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
  # echo "DB GET ", key.toHex
  db.tbl.getOrDefault(@key).value

proc del*(db: MemDB, key: openarray[byte]) =
  # The database should ensure that the empty key is always active:
  if key != emptyRlpHash.data:
    let key = @key
    db.tbl.withValue(key, v):
      dec v.refCount
      if v.refCount <= 0:
        db.tbl.del(key)

proc contains*(db: MemDB, key: openarray[byte]): bool =
  db.tbl.hasKey(@key)

template printPair(k, v) =
  echo "KEY ", k.toHex, " = ", v.toHex # rlpFromBytes(@v.toRange).inspect

proc put*(db: MemDB, key, val: openarray[byte]) =
  # printPair(key, val)
  let key = @key
  db.tbl.withValue(key, v) do:
    inc v.refCount
  do:
    db.tbl[key] = MemDbRecord(refCount: 1, value: @val)

proc newMemDB*: MemDB =
  result.new
  result.tbl = initTable[Bytes, MemDbRecord]()
  put(result, emptyRlpHash.data, emptyRlp.toOpenArray)

proc len*(db: MemDB): int =
  db.tbl.len

#static:
#  assert MemDB is TrieDatabaseConcept

