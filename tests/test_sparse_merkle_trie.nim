import
  eth_trie/[memdb, sparse_merkle, constants, types],
  unittest, test_utils, random

suite "sparse merkle trie":
  randomize()
  var kv_pairs = randKVPair(20)
  let vals = randList(int, randGen(1, 99), randGen(50, 100))

  test "basic get/set":
    var db = trieDB newMemDB()
    var trie = initSparseMerkleTrie(db)
    
    trie.set("12345678901234567890", "apple")
    let val = trie.get("12345678901234567890")
    check val == toRange("apple")
    
    #for c in kv_pairs:
    #  check trie.exists(c.key) == false
    #  trie.set(c.key, c.value)
    #
    #let prevRoot = trie.getRootHash()
    #for c in kv_pairs:
    #  check trie.get(c.key) == toRange(c.value)
    #  trie.delete(c.key)
    #  
    #for c in kv_pairs:
    #  check trie.exists(c.key) == false
    #  
    #check trie.getRootHash() == keccakHash(emptyNodeHashes[0], emptyNodeHashes[0]).toRange