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

proc randStringList(strGen, listGen: RandGen): seq[string] =
  let listLen = listGen.getVal()
  result = newSeqOfCap[string](listLen)
  var set = initSet[string]()
  for len in 0..<listLen:
    while true:
      let x = randString(strGen.getVal())
      if x notin set:
        result.add x
        set.incl x
        break

proc randKVPair(): seq[KVPair] =
  const listLen = 100
  let keys = randStringList(randGen(32, 32), randGen(listLen, listLen))
  let vals = randStringList(randGen(1, 100), randGen(listLen, listLen))

  result = newSeq[KVPair](listLen)
  for i in 0..<listLen:
    result[i] = KVPair(key: keys[i], value: vals[i])

import streams

#proc main() =
#  randomize()
#  var kv_pairs = randKVPair()
#  var f = newFileStream("data.dat", fmWrite)
#  f.write(kv_pairs.len)
#  for c in kv_pairs:
#    f.write(c.key.len)
#    f.write(c.value.len)
#    f.write(c.key)
#    f.write(c.value)
#  f.close()

proc loadKVPair(): seq[KVPair] =
  var f = newFileStream("data.dat")
  var len: int
  len = f.readInt64().int
  result = newSeq[KVPair](len)
  for i in 0..<len:
    var keyLen, valLen: int
    keyLen = f.readInt64().int
    valLen = f.readInt64().int
    result[i] = KVPair(key: f.readStr(keyLen), value: f.readStr(valLen))
  f.close()

proc main() =
  var kv_pairs = loadKVPair()
  var db = newMemDB()
  var trie = initBinaryTrie(db)
  var i = 0
  for c in kv_pairs:
    #echo c.key, " ", c.value
    #echo "-----: ", i
    trie.set(c.key, c.value)
    let x = toRange(c.value)
    let y = trie.get(c.key)
    if x != y:
      assert(false)
    inc i


main()

#test "binary trie different order insert":
#  randomize()
#  var kv_pairs = randKVPair()
#  #for _ in 0..<3: # repeat 3 times
#  var db = newMemDB()
#  var trie = initBinaryTrie(db)
#  random.shuffle(kv_pairs)
#
#  var i = 0
#  for c in kv_pairs:
#    #echo c.key, " ", c.value
#    echo i
#    trie.set(c.key, c.value)
#    check trie.get(c.key) == toRange(c.value)
#    inc i

#assert result is BLANK_HASH or trie.root_hash == result
#result = trie.root_hash
## insert already exist key/value
#trie.set(kv_pairs[0][0], kv_pairs[0][1])
#assert trie.root_hash == result
## Delete all key/value
#random.shuffle(kv_pairs)
#for k, v in kv_pairs:
#    trie.delete(k)
#assert trie.root_hash == BLANK_HASH
