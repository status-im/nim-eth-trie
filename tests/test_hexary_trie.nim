import
  unittest, strutils, sequtils,
  ranges/typedranges, eth_trie/[hexary, types, memdb],
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

