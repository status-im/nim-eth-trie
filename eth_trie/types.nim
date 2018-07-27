import
  nimcrypto/hash, rlp/types, eth_common/eth_types

export KeccakHash

type
  TrieDatabaseConcept* = concept DB
    mixin put, del, get

    put(var DB, KeccakHash, BytesRange)
    del(var DB, KeccakHash)
    get(DB, KeccakHash) is Bytes
    contains(DB, KeccakHash) is bool

# XXX: poor's man vtref types

type
  PutProc = proc (db: RootRef, key, val: openarray[byte])
  GetProc = proc (db: RootRef, key: openarray[byte]): Bytes
  DelProc = proc (db: RootRef, key: openarray[byte])
  ContainsProc = proc (db: RootRef, key: openarray[byte]): bool

  TrieDatabaseRef* = object
    obj: RootRef
    putProc: PutProc
    getProc: GetProc
    delProc: DelProc
    containsProc: ContainsProc

proc putImpl[T](db: RootRef, key, val: openarray[byte]) =
  mixin put
  put(T(db), key, val)

proc getImpl[T](db: RootRef, key: openarray[byte]): Bytes =
  mixin get
  return get(T(db), key)

proc delImpl[T](db: RootRef, key: openarray[byte]) =
  mixin del
  del(T(db), key)

proc containsImpl[T](db: RootRef, key: openarray[byte]): bool =
  mixin contains
  return contains(T(db), key)

proc trieDB*[T: RootRef](x: T): TrieDatabaseRef =
  result.obj = x
  mixin del, get, put
  result.putProc = putImpl[T]
  result.getProc = getImpl[T]
  result.delProc = delImpl[T]
  result.containsProc = containsImpl[T]

proc put*(db: TrieDatabaseRef, key, val: openarray[byte]) =
  (db.putProc)(db.obj, key, val)

proc get*(db: TrieDatabaseRef, key: openarray[byte]): Bytes =
  return (db.getProc)(db.obj, key)

proc del*(db: TrieDatabaseRef, key: openarray[byte]) =
  (db.delProc)(db.obj, key)

proc contains*(db: TrieDatabaseRef, key: openarray[byte]): bool =
  return db.containsProc(db.obj, key)

