import
  ethereum_trie/utils/binaries, test_utils,
  rlp/types as rlpTypes, random

func generateBytes(len: int): BytesRange =
  var res = newRange[byte](len)
  for i in 0..<len:
    res[i] = byte(i mod 0xFF)
  result = res

proc generateRandomZeroOne(len: int): BytesRange =
  random.randomize()
  var res = newSeq[byte](len)
  for i in 0..<len:
    res[i] = byte(random.rand(1) + ord('0'))
  result = toRange(res)

# cannot use unittest here, because it alter the ranges
# in some misterious way
block basic_test:
  let bin = encodeToBin(br("ASCII"))
  let binbin = br("0100000101010011010000110100100101001001")
  doAssert(bin == binbin)

  let asc = decodeFromBin(binbin)
  doAssert asc == br("ASCII")

block test_full_8bit:
  for i in 0..<1024:
    let ori = generateBytes(i)
    let bin = ori.encodeToBin()
    let res = bin.decodeFromBin()
    doAssert ori == res

block test_keypath_encoding:
  for i in 0..<1024:
    var value = generateRandomZeroOne(i)
    var s = toSeq(value)
    var bk = encodeFromBinKeypath(value)
    var res = decodeToBinKeypath(bk)
    doAssert res == value

echo "OK"
