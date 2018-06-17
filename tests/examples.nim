import
  ethereum_trie/[memdb, binary, utils, branches]

var db = newMemDB()
var trie = initBinaryTrie(db)
trie.set("key1", "value1")
trie.set("key2", "value2")
assert trie.get("key1") == "value1".toRange
assert trie.get("key2") == "value2".toRange

echo db[].len
var branchs = getWitness(db, trie.getRootHash, zeroBytesRange)
echo branchs.len

# delete all subtrie with key prefixes "key"
trie.deleteSubtrie("key")
assert trie.get("key1") == zeroBytesRange
assert trie.get("key2") == zeroBytesRange

echo db[].len
branchs = getWitness(db, trie.getRootHash, zeroBytesRange)
echo branchs.len

trie["moon"] = "sun"
assert "moon" in trie
assert trie["moon"] == "sun".toRange
