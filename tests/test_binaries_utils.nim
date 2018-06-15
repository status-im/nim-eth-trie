import
  ethereum_trie/utils/binaries, test_utils,
  rlp/types as rlpTypes, random, unittest

func generateBytes(len: int): BytesRange =
  var res = newRange[byte](len)
  for i in 0..<len:
    res[i] = byte(i mod 0xFF)
  result = res

proc generateRandomZeroOne(len: int): Bytes =
  random.randomize()
  result = newSeq[byte](len)
  for i in 0..<len:
    result[i] = byte(random.rand(1))

suite "binaries utils":

  test "basic":
    let binbin = parseBin("0100000101010011010000110100100101001001")
    check(encodeToBin(br("ASCII")) == binbin)

    let asc = decodeFromBin(binbin)
    check(asc == b("ASCII"))

  test "full 8bit":
    for i in 0..1024:
      let ori = generateBytes(i)
      let bin = ori.encodeToBin()
      let res = bin.decodeFromBin().toRange
      check(ori == res)

  test "keypath encoding":
    for i in 0..1024:
      var value = generateRandomZeroOne(i)
      var bk = encodeFromBinKeypath(value.toRange)
      var res = decodeToBinKeypath(bk.toRange)
      check(res.len == value.len)
      check(res == value)
