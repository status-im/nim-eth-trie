import
  eth_trie/bitvector, test_utils,
  rlp/types as rlpTypes, random, unittest

suite "bitvector":

  test "basic":
    var a = @[0b10101010_11110000_00001111_01010101'u32]
    var b = toBitVector(@[0b10101010_00000000_00000000_11111111'u32], 8)
    var c = toBitVector(@[0b11110000_00001111_00000000_00000000'u32], 16)
    var d = toBitVector(@[0b00001111_00000000_00000000_00000000'u32], 8)
    var e = toBitVector(@[0b01010101_00000000_00000000_00000000'u32], 8)

    var m = toBitVector(a)
    var n = m[0..7]
    check n == b
    check n.len == 8
    check b.len == 8
    check c == m[8..23]
    check $(d) == "00001111"
    check $(e) == "01010101"

    var f = e.getBits(0, 4)
    check f == 0b0101

    let k = n & d
    check(k.len == n.len + d.len)
    check($k == $n & $d)

    check $toBitVector(@['A','S','C','I','I']) == "0100000101010011010000110100100101001001"

  test "concat operator":
    randomize()
    for i in 0..<256:
      let x = genBitVec(i)
      let y = genBitVec(i)
      var z = x & y
      check z.len == x.len + y.len
      check($z == $x & $y)

  test "get set bits":
    for i in 0..<256:
      # produce random vector
      var x = genBitVec(i)
      var y = genBitVec(i)
      for idx, bit in x:
        y[idx] = bit
      check x == y
