import
  ethereum_trie/[memdb, binary, utils]
  
var db = newMemDB()
var trie = initBinaryTrie(db)
trie.set("key1", "value1")
trie.set("key2", "value2")
assert trie.get("key1") == "value1".toRange
assert trie.get("key2") == "value2".toRange

# delete all subtrie with key prefixes "key"
trie.deleteSubtrie("key") 
assert trie.get("key1") == zeroBytesRange
assert trie.get("key2") == zeroBytesRange

trie["moon"] = "sun"
assert "moon" in trie
assert trie["moon"] == "sun".toRange
