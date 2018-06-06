import
  keccak_tiny, ethereum_trie/types, binaries, rlp/types as rlpTypes

export
  types

type
  TrieNodeKey = object
    hash: KeccakHash
    usedBytes: uint8

  BinaryTrie[DB: TrieDatabase] = object
    dbLink: ref DB
    rootHash: TrieNodeKey

let
  BLANK_HASH     = hashFromHex("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
  zeroBytesRange = Range[byte]()
  
converter toTrieNodeKey(hash: KeccakHash): TrieNodeKey =
  result.hash = hash
  result.usedBytes = 32
  
converter toTrieNodeKey(hash: BytesRange): TrieNodeKey =
  assert hash.len == 32
  for i in 0..<32:
    result.hash.data[i] = uint8(hash[i])
  result.usedBytes = 32
  
proc initBinaryTrie*[DB](db: ref DB): BinaryTrie[DB] =
  result.dbLink = db
  result.rootHash = BLANK_HASH.toTrieNodeKey

proc `==`(a, b: BytesRange): bool =
  if a.len != b.len: return false
  for i in 0..<a.len:
    if a[i] != b[i]: return false
  result = true
  
proc getAux[DB](self: BinaryTrie[DB], nodeHash: TrieNodeKey, keyPath: BinVector): BytesRange =
  # Empty trie
  if nodeHash == BLANK_HASH:
    return zeroBytesRange

  let (nodeType, leftChild, rightChild) = parseNode(self.dbLink[].get(nodeHash.hash).toRange)
  # Key-value node descend
  if nodeType == LEAF_TYPE:
    if keyPath.len != 0: 
      return zeroBytesRange
    return rightChild
  elif nodeType == KV_TYPE:
    # Keypath too short
    if keyPath.len == 0:
      return zeroBytesRange
    if keyPath[0..leftChild.len] == leftChild:
      return self.getAux(rightChild, keyPath[leftChild.len.. ^1])
    else:
      return zeroBytesRange
  # Branch node descend
  elif nodeType == BRANCH_TYPE:
    # Keypath too short
    if keyPath.len == 0:
      return zeroBytesRange
    if keyPath[0] == byte('0'):
      return self.getAux(leftChild, keyPath[1..^1])
    else:
      return self.getAux(rightChild, keyPath[1..^1])
      
proc get[DB](self: BinaryTrie[DB], key: BytesRange): BytesRange =
  return self.getAux(self.root_hash, encode_to_bin(key))

import ethereum_trie/memdb

proc main() =
  var db = newMemDB()
  var trie = initBinaryTrie(db)
    
  var key = toRange(@[1.byte, 2.byte, 3.byte])
  var res = trie.get(key)
  
main()


