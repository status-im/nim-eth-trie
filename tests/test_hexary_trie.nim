import
  unittest, strutils, sequtils, os,
  ranges/typedranges, eth_trie/[hexary, types, memdb], nimcrypto/utils,
  test_utils

template put(t: HexaryTrie|SecureHexaryTrie, key, val: string) =
  t.put(key.toBytesRange, val.toBytesRange)

template del(t: HexaryTrie|SecureHexaryTrie, key) =
  t.del(key.toBytesRange)

template get(t: HexaryTrie|SecureHexaryTrie, key): auto =
  t.get(key.toBytesRange)

suite "hexary trie":
  setup:
    var
      db = trieDB newMemDB()
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

