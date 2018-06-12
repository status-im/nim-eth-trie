import
  nimcrypto/hash, rlp/types

type
  KeccakHash* = MDigest[256]

  TrieDatabase* = concept DB
    mixin put, del, get

    put(var DB, KeccakHash, BytesRange) is bool
    del(var DB, KeccakHash) is bool
    get(DB, KeccakHash) is Bytes

