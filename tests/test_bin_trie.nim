import
  ethereum_trie/[memdb, binary, utils], rlp/types,
  random, sets, unittest

type
  RandGen[T] = object
    minVal, maxVal: T

  KVPair = ref object
    key: string
    value: string

proc randGen[T](minVal, maxVal: T): RandGen[T] =
  assert(minVal <= maxVal)
  result.minVal = minVal
  result.maxVal = maxVal

proc getVal[T](x: RandGen[T]): T =
  if x.minVal == x.maxVal: return x.minVal
  rand(x.minVal..x.maxVal)

proc randString(len: int): string =
  result = newString(len)
  for i in 0..<len:
    result[i] = rand(255).char

proc randPrimitives[T](val: int): T =
  when T is string:
    randString(val)
  elif T is int:
    rand(val)

proc randList(T: typedesc, strGen, listGen: RandGen): seq[T] =
  let listLen = listGen.getVal()
  result = newSeqOfCap[T](listLen)
  var set = initSet[T]()
  for len in 0..<listLen:
    while true:
      let x = randPrimitives[T](strGen.getVal())
      if x notin set:
        result.add x
        set.incl x
        break

proc randKVPair(): seq[KVPair] =
  const listLen = 100
  let keys = randList(string, randGen(32, 32), randGen(listLen, listLen))
  let vals = randList(string, randGen(1, 100), randGen(listLen, listLen))

  result = newSeq[KVPair](listLen)
  for i in 0..<listLen:
    result[i] = KVPair(key: keys[i], value: vals[i])

suite "binary trie":

  test "different order insert":
    randomize()
    var kv_pairs = randKVPair()
    var result = BLANK_HASH
    for _ in 0..<3: # repeat 3 times
      var db = newMemDB()
      var trie = initBinaryTrie(db)
      random.shuffle(kv_pairs)

      for c in kv_pairs:
        trie.set(c.key, c.value)
        let x = trie.get(c.key)
        let y = toRange(c.value)
        check y == x

      check result == BLANK_HASH or trie.rootHash == result
      result = trie.rootHash

      # insert already exist key/value
      trie.set(kv_pairs[0].key, kv_pairs[0].value)
      check trie.rootHash == result

      # Delete all key/value
      random.shuffle(kv_pairs)
      for c in kv_pairs:
        trie.delete(c.key)
      check trie.rootHash == BLANK_HASH

  const delSubtrieData = [
    (("\x12\x34\x56\x78", "78"), ("\x12\x34\x56\x79", "79"), "\x12\x34\x56", true, false),
    (("\x12\x34\x56\x78", "78"), ("\x12\x34\x56\xff", "ff"), "\x12\x34\x56", true, false),
    (("\x12\x34\x56\x78", "78"), ("\x12\x34\x56\x79", "79"), "\x12\x34\x57", false, false),
    (("\x12\x34\x56\x78", "78"), ("\x12\x34\x56\x79", "79"), "\x12\x34\x56\x78\x9a", false, true)
    ]

  test "delete subtrie":
    for data in delSubtrieData:
      var db = newMemDB()
      var trie = initBinaryTrie(db)

      let kv1 = data[0]
      let kv2 = data[1]
      let key_to_be_deleted = data[2]
      let will_delete = data[3]
      let will_raise_error = data[4]

      # First test case, delete subtrie of a kv node
      trie.set(kv1[0], kv1[1])
      trie.set(kv2[0], kv2[1])
      check trie.get(kv1[0]) == toRange(kv1[1])
      check trie.get(kv2[0]) == toRange(kv2[1])

      if will_delete:
        trie.deleteSubtrie(key_to_be_deleted)
        check trie.get(kv1[0]) == zeroBytesRange
        check trie.get(kv2[0]) == zeroBytesRange
        check trie.rootHash == BLANK_HASH
      else:
        if will_raise_error:
          try:
            trie.deleteSubtrie(key_to_be_deleted)
          except NodeOverrideError as E:
            discard
          except:
            doAssert(false)
        else:
          let root_hash_before_delete = trie.rootHash
          trie.deleteSubtrie(key_to_be_deleted)
          check trie.get(kv1[0]) == toRange(kv1[1])
          check trie.get(kv2[0]) == toRange(kv2[1])
          check trie.rootHash == root_hash_before_delete

  const invalidKeyData = [
    ("\x12\x34\x56", false),
    ("\x12\x34\x56\x77", false),
    ("\x12\x34\x56\x78\x9a", true),
    ("\x12\x34\x56\x79\xab", true),
    ("\xab\xcd\xef", false)
    ]

  test "invalid key":
   for data in invalidKeyData:
      var db = newMemDB()
      var trie = initBinaryTrie(db)

      trie.set("\x12\x34\x56\x78", "78")
      trie.set("\x12\x34\x56\x79", "79")

      let invalidKey = data[0]
      let if_error = data[1]

      check trie.get(invalidKey) == zeroBytesRange

      if if_error:
        try:
          trie.delete(invalidKey)
        except NodeOverrideError as E:
          discard
        except:
          doAssert(false)
      else:
        let previous_root_hash = trie.rootHash
        trie.delete(invalidKey)
        check previous_root_hash == trie.rootHash

  test "update value":
    let keys = randList(string, randGen(32, 32), randGen(100, 100))
    let vals = randList(int, randGen(0, 99), randGen(50, 50))
    var db = newMemDB()
    var trie = initBinaryTrie(db)
    for key in keys:
      trie.set(key, "old")

    var current_root = trie.rootHash
    for i in vals:
      trie.set(keys[i], "old")
      check current_root == trie.rootHash
      trie.set(keys[i], "new")
      check current_root != trie.rootHash
      check trie.get(keys[i]) == toRange("new")
      current_root = trie.rootHash
