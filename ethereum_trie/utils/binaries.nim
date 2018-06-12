import rlp/types, strutils, ethereum_trie/utils

type
  BinVector* = BytesRange

const
  binaryZero* = byte(0x00)
  binaryOne* = byte(0x01)

func generateMask(): array[8, byte] {.compileTime.} =
  for i in 0..<8:
    result[7 - i] = byte(1 shl i)

const
  byteMask = generateMask()
  TWO_BITS = ["\x00\x00", "\x00\x01", "\x01\x00", "\x01\x01"]
  PREFIX_00 = "\x00\x00"
  PREFIX_100000 = "\x01\x00\x00\x00\x00\x00"

proc encodeToBin*(value: BytesRange): Bytes =
  ## ASCII -> "0100000101010011010000110100100101001001"
  result = newSeq[byte](value.len * 8)
  var i = 0
  for v in value:
    for m in byteMask:
      result[i] = if (m and v) != 0: binaryOne else: binaryZero
      inc i

proc decodeFromBin*(bin: Bytes): Bytes =
  ## "0100000101010011010000110100100101001001" -> ASCII
  assert (bin.len mod 8) == 0
  result = newSeq[byte](bin.len div 8)
  var x = 0
  for i in 0..<result.len:
    var b = byte(0)
    for y in 0..<8:
      if bin[x] == binaryOne:
        b = b or byteMask[y]
      inc x
    result[i] = b

proc encodeFromBinKeypath*(bin: BinVector): Bytes =
  ## Encodes a sequence of 0s and 1s into tightly packed bytes
  ## Used in encoding key path of a KV-NODE
  let
    padding = repeat(binaryZero.char, ((not bin.len) + 1) and 3) # modulo 4 padding
    padded_bin_len = bin.len + padding.len
    prefix = TWO_BITS[bin.len mod 4]

  if padded_bin_len mod 8 == 4:
    let prefixVal = toRange(PREFIX_00 & prefix & padding)
    return decodeFromBin(prefixVal & bin)
  else:
    let prefixVal = toRange(PREFIX_100000 & prefix & padding)
    return decodeFromBin(prefixVal & bin)

proc decodeToBinKeypath*(path: BytesRange): Bytes =
  ## Decodes bytes into a sequence of 0s and 1s
  ## Used in decoding key path of a KV-NODE
  var path = encodeToBin(path)
  if path[0] == binaryOne:
    path = path[4..^1]

  assert path[0] == binaryZero
  assert path[1] == binaryZero
  var bits = path[2].int shl 1
  bits = bits or path[3].int

  if path.len > 4:
    result = path[4+((4 - bits) mod 4)..^1]
  else:
    result = @[]
