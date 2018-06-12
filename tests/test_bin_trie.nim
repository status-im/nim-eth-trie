import ethereum_trie/[memdb, binary, utils], rlp/types

proc main() =
  var db = newMemDB()
  var trie = initBinaryTrie(db)

  var key = toRange(@[1.byte, 2.byte, 3.byte])
  var res = trie.get(key)
  #let hash = trie.hashAndSave(key)
  #echo toHex(hash)
  trie.set(key, key)

main()
