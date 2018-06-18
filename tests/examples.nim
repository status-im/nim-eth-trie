import
  ethereum_trie/[memdb, binary, utils, branches]

var db = newMemDB()
var trie = initBinaryTrie(db)
trie.set("key1", "value1")
trie.set("key2", "value2")
assert trie.get("key1") == "value1".toRange
assert trie.get("key2") == "value2".toRange

assert checkIfBranchExist(db, trie.getRootHash(), "key") == true
assert checkIfBranchExist(db, trie.getRootHash(), "key1") == true
assert checkIfBranchExist(db, trie.getRootHash(), "ken") == false
assert checkIfBranchExist(db, trie.getRootHash(), "key123") == false

let beforeDeleteLen = db[].len
var branchs = getWitness(db, trie.getRootHash, zeroBytesRange)
# set operation create new intermediate entries
assert branchs.len < beforeDeleteLen

# delete all subtrie with key prefixes "key"
trie.deleteSubtrie("key")
assert trie.get("key1") == zeroBytesRange
assert trie.get("key2") == zeroBytesRange

# `delete` and `deleteSubtrie` not actually delete the nodes
assert db[].len == beforeDeleteLen
branchs = getWitness(db, trie.getRootHash, zeroBytesRange)
assert branchs.len == 0

# dictionary syntax API
trie["moon"] = "sun"
assert "moon" in trie
assert trie["moon"] == "sun".toRange
