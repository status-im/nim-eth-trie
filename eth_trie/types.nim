import
  nimcrypto/hash, rlp/types

type
  KeccakHash* = MDigest[256]

  TrieDatabaseConcept* = concept DB
    mixin put, del, get

    put(var DB, KeccakHash, BytesRange) is bool
    del(var DB, KeccakHash) is bool
    get(DB, KeccakHash) is Bytes
    contains(DB, KeccakHash) is bool

# XXX: poor's man vtref types

type
  PutProc = proc (db: RootRef, key: KeccakHash, data: BytesRange): bool
  GetProc = proc (db: RootRef, key: KeccakHash): Bytes
  DelProc = proc (db: RootRef, key: KeccakHash): bool
  ContainsProc = proc (db: RootRef, key: KeccakHash): bool

  TrieDatabaseRef* = object
    obj: RootRef
    putProc: PutProc
    getProc: GetProc
    delProc: DelProc
    containsProc: ContainsProc

proc putImpl[T](db: RootRef, key: KeccakHash, data: BytesRange): bool =
  type DBRef = ref T
  mixin put
  return put(DBRef(db)[], key, data)

proc getImpl[T](db: RootRef, key: KeccakHash): Bytes =
  type DBRef = ref T
  mixin get
  return get(DBRef(db)[], key)

proc delImpl[T](db: RootRef, key: KeccakHash): bool =
  type DBRef = ref T
  mixin del
  return del(DBRef(db)[], key)

proc containsImpl[T](db: RootRef, key: KeccakHash): bool =
  type DBRef = ref T
  mixin contains
  return contains(DBRef(db)[], key)

proc trieDB*[T](x: ref T): TrieDatabaseRef =
  result.obj = x
  mixin del, get, put
  result.putProc = putImpl[T]
  result.getProc = getImpl[T]
  result.delProc = delImpl[T]
  result.containsProc = containsImpl[T]

proc put*(db: TrieDatabaseRef, key: KeccakHash, data: BytesRange): bool =
  return (db.putProc)(db.obj, key, data)

proc get*(db: TrieDatabaseRef, key: KeccakHash): Bytes =
  return (db.getProc)(db.obj, key)

proc del*(db: TrieDatabaseRef, key: KeccakHash): bool =
  return (db.delProc)(db.obj, key)

proc contains*(db: TrieDatabaseRef, key: KeccakHash): bool =
  return db.containsProc(db.obj, key)
