import
  eth_trie/[memdb, sparse_merkle, constants, types],
  unittest, test_utils, random

suite "sparse merkle trie":
  randomize()
  var kv_pairs = randKVPair(20)
  var numbers = randList(int, randGen(1, 99), randGen(50, 100))
  var db = trieDB newMemDB()
  var trie = initSparseMerkleTrie(db)

  test "basic set":
    for c in kv_pairs:
      check trie.exists(c.key) == false
      trie.set(c.key, c.value)

  let prevRoot = trie.getRootHash()
  test "basic get":
    for i, c in kv_pairs:
      let x = trie.get(c.key)
      let y = toRange(c.value)
      check x == y
      trie.delete(c.key)

    for c in kv_pairs:
      check trie.exists(c.key) == false

    check trie.getRootHash() == keccakHash(emptyNodeHashes[0], emptyNodeHashes[0]).toRange

  test "single update set":
    random.shuffle(kv_pairs)
    for c in kv_pairs:
      trie.set(c.key, c.value)

    # Check trie root remains the same even in different insert order
    check trie.getRootHash() == prevRoot

  let prior_to_update_root = trie.getRootHash()
  test "single update get":
    for i in numbers:
      # If new value is the same as current value, skip the update
      if toRange($i) == trie.get(kv_pairs[i].key):
        continue
      # Update
      trie.set(kv_pairs[i].key, $i)
      check trie.get(kv_pairs[i].key) == toRange($i)
      check trie.getRootHash() != prior_to_update_root

      # Un-update
      trie.set(kv_pairs[i].key, kv_pairs[i].value)
      check trie.getRootHash == prior_to_update_root

  test "batch update with different update order":
    # First batch update
    for i in numbers:
      trie.set(kv_pairs[i].key, $i)

    let batch_updated_root = trie.getRootHash()

    # Un-update
    random.shuffle(numbers)
    for i in numbers:
      trie.set(kv_pairs[i].key, kv_pairs[i].value)

    check trie.getRootHash() == prior_to_update_root

    # Second batch update
    random.shuffle(numbers)
    for i in numbers:
        trie.set(kv_pairs[i].key, $i)

    check trie.getRootHash() == batch_updated_root

  test "dictionary API":
    trie[kv_pairs[0].key] = kv_pairs[0].value
    let x = trie[kv_pairs[0].key]
    let y = toRange(kv_pairs[0].value)
    check x == y
    check kv_pairs[0].key in trie

