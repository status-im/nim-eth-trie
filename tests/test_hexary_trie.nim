import
  unittest, strutils, sequtils, os,
  ranges/typedranges, eth_trie/[hexary, db], nimcrypto/utils,
  test_utils, algorithm, rlp/types as rlpTypes

template put(t: HexaryTrie|SecureHexaryTrie, key, val: string) =
  t.put(key.toBytesRange, val.toBytesRange)

template del(t: HexaryTrie|SecureHexaryTrie, key) =
  t.del(key.toBytesRange)

template get(t: HexaryTrie|SecureHexaryTrie, key): auto =
  t.get(key.toBytesRange)

suite "hexary trie":
  setup:
    var
      db = newMemoryDB()
      tr = initHexaryTrie(db)

  test "ref-counted keys crash":
    proc addKey(intKey: int) =
      var key = newSeqWith(20, 0.byte)
      key[19] = byte(intKey)
      var data = newSeqWith(29, 1.byte)

      var k = key.toRange

      let v = tr.get(k)
      doAssert(v.len == 0)

      tr.put(k, toRange(data))

    addKey(166)
    addKey(193)
    addKey(7)
    addKey(101)
    addKey(159)
    addKey(187)
    addKey(206)
    addKey(242)
    addKey(94)
    addKey(171)
    addKey(14)
    addKey(143)
    addKey(237)
    addKey(148)
    addKey(181)
    addKey(147)
    addKey(45)
    addKey(81)
    addKey(77)
    addKey(123)
    addKey(35)
    addKey(24)
    addKey(188)
    addKey(136)


  const genesisAccounts = "tests/cases/mainnet-genesis-accounts.txt"
  if fileExists(genesisAccounts):
    # This test is optional because it takes a while to run and the
    # verification is already being part of Nimbus (see genesis.nim).
    #
    # On the other hand, it's useful to be able to debug just the trie
    # code if problems arise. You can download the genesis-accounts file
    # using the the following command at the root at the repo:
    #
    # wget https://gist.github.com/zah/f3a7d325a71d35df3c2606af05d30910/raw/d8bf8fed3d2760f0054cebf4de254a0564a87322/mainnet-genesis-accounts.txt -P tests/cases
    test "genesis hash":
      for line in lines(genesisAccounts):
        var parts = line.split(" ")
        var
          key = fromHex(parts[0])
          val = fromHex(parts[1])

        SecureHexaryTrie(tr).put(key.toRange, val.toRange)

      check tr.rootHashHex == "D7F8974FB5AC78D9AC099B9AD5018BEDC2CE0A72DAD1827A1709DA30580F0544"

  proc lexComp(a, b: BytesRange): bool =
    var
      x = 0
      y = 0
      xlen = a.len
      ylen = b.len

    while x != xlen:
      if y == ylen or b[y] < a[x]: return false
      elif a[x] < b[y]: return true
      inc x
      inc y

    result = y != ylen

  proc cmp(a, b: BytesRange): int =
    if a == b: return 0
    if a.lexComp(b): return 1
    return -1

  test "get leaves":
    var
      memdb = newMemoryDB()
      trie = initHexaryTrie(memdb)
      keys = [
        "key".toBytesRange,
        "abc".toBytesRange,
        "hola".toBytesRange,
        "bubble".toBytesRange
      ]

      vals = [
        "hello".toBytesRange,
        "world".toBytesRange,
        "block".toBytesRange,
        "chain".toBytesRange
      ]

    for i in 0 ..< keys.len:
      trie.put(keys[i], vals[i])

    var leaves = trie.getLeaves()
    leaves.sort(cmp)
    vals.sort(cmp)
    check leaves == vals

  test "get leaves with random data":
    var
      memdb = newMemoryDB()
      trie = initHexaryTrie(memdb)
      keys = randList(BytesRange, randGen(5, 32), randGen(10, 10))
      vals = randList(BytesRange, randGen(5, 7), randGen(10, 10))

      keys2 = randList(BytesRange, randGen(5, 30), randGen(15, 15))
      vals2 = randList(BytesRange, randGen(5, 7), randGen(15, 15))

    for i in 0 ..< keys.len:
      trie.put(keys[i], vals[i])

    for i in 0 ..< keys.len:
      check trie.get(keys[i]) == vals[i]

    var leaves = trie.getLeaves()
    leaves.sort(cmp)
    vals.sort(cmp)
    check leaves == vals

    let rootHash = trie.rootHash
    for i in 0 ..< keys2.len:
      trie.put(keys2[i], vals2[i])
    var trie2 = initHexaryTrie(memdb, rootHash)

    leaves = trie2.getLeaves()
    check leaves != vals

    var leaves2 = trie.getLeaves()
    vals2.add vals
    leaves2.sort(cmp)
    vals2.sort(cmp)
    check leaves2 == vals2
