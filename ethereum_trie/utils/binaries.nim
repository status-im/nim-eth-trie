import rlp/types, strutils

type
  BinVector* = BytesRange

const
  binaryZero = byte('0')
  binaryOne = byte('1')

func generateMask(): array[8, byte] {.compileTime.} =
  for i in 0..<8:
    result[7 - i] = byte(1 shl i)

const
  byteMask = generateMask()
  TWO_BITS = ["00", "01", "10", "11"]
  PREFIX_00 = "00"
  PREFIX_100000 = "100000"

proc encodeToBin*(value: BytesRange): BinVector =
  ## ASCII -> "0100000101010011010000110100100101001001"
  var bv = newSeq[byte](value.len * 8)
  var i = 0
  for v in value:
    for m in byteMask:
      bv[i] = if (m and v) != 0: binaryOne else: binaryZero
      inc i
  result = toRange(bv)

proc decodeFromBin*(bin: BinVector): BytesRange =
  ## "0100000101010011010000110100100101001001" -> ASCII
  assert (bin.len mod 8) == 0
  var ss = newSeq[byte](bin.len div 8)
  var x = 0
  for i in 0..<ss.len:
    var b = byte(0)
    for y in 0..<8:
      if bin[x] == binaryOne:
        b = b or byteMask[y]
      inc x
    ss[i] = b
  result = toRange(ss)

func concat[T](a: T, b: BinVector): BinVector =
  var bin = newSeq[byte](a.len + b.len)
  for i in 0..<a.len: bin[i] = byte(a[i])
  for i in 0..<b.len: bin[i+a.len] = byte(b[i])
  result = toRange(bin)

func encodeFromBinKeypath*(bin: BinVector): BytesRange =
  ## Encodes a sequence of 0s and 1s into tightly packed bytes
  ## Used in encoding key path of a KV-NODE
  let
    padding = repeat(binaryZero.char, ((not bin.len) + 1) and 3) # modulo 4 padding
    padded_bin_len = bin.len + padding.len
    prefix = TWO_BITS[bin.len mod 4]

  if padded_bin_len mod 8 == 4:
    let prefixVal = PREFIX_00 & prefix & padding
    return decodeFromBin(concat(prefixVal, bin))
  else:
    let prefixVal = PREFIX_100000 & prefix & padding
    return decodeFromBin(concat(prefixVal, bin))

func cmp[T](a: BytesRange, b: T): bool =
  if a.len != b.len: return false
  for i in 0..<a.len:
    if a[i].byte != b[i].byte: return false
  true

func index[T](a: openArray[T], b: BytesRange): int =
  result = -1
  for i in 0..<a.len:
    if cmp(b, a[i]): return i

func decodeToBinKeypath*(path: BytesRange): BinVector =
  # Decodes bytes into a sequence of 0s and 1s
  # Used in decoding key path of a KV-NODE
  var path = encodeToBin(path)
  if path[0] == binaryOne:
    path = path[4..^1]

  assert path[0..<2].cmp(PREFIX_00)
  let paddedLen = TWO_BITS.index(path[2..<4])
  if path.len > 4:
    result = toSeq(path[4+((4 - paddedLen) mod 4)..^1]).toRange
