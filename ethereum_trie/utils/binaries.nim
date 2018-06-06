import rlp/types, strutils

type
  BinVector* = BytesRange

#proc len*(self: BinVector): int =
#  BytesRange(self).len
#
#iterator items*(self: BinVector): byte =
#  for c in BytesRange(self): yield c
#
#proc `[]`*(self: BinVector, i: int): byte =
#  BytesRange(self)[i]

proc generateMask(): array[8, byte] {.compileTime.} =
  for i in 0..<8:
    result[7 - i] = byte(1 shl i)

const
  byteMask = generateMask()
  TWO_BITS = ["00", "01", "10", "11"]
  PREFIX_00 = "00"
  PREFIX_100000 = "100000"

func encode_to_bin*(value: BytesRange): BinVector =
  ## ASCII -> 0100000101010111010000110100100101001001
  var bv = newRange[byte](value.len * 8)
  var i = 0
  for v in value:
    for m in byteMask:
      bv[i] = if (m and v) != 0: byte('1') else: byte('0')
      inc i
  result = bv.BinVector

func decode_from_bin*(bin: BinVector): Bytes =
  ## 0100000101010111010000110100100101001001 -> ASCII
  assert (bin.len mod 8) == 0
  result = newSeq[byte](bin.len div 8)
  var x = 0
  for i in 0..<result.len:
    for y in 0..<8:
      if bin[x] == byte('1'):
        result[i] = result[i] or byteMask[y]
      inc x

proc concat[T](a: T, b: BinVector): BinVector =
  var bin = newRange[byte](a.len + b.len)
  for i in 0..<a.len: bin[i] = byte(a[i])
  for i in 0..<b.len: bin[i+a.len] = byte(b[i])
  result = bin.BinVector

func encode_from_bin_keypath*(bin: BinVector): Bytes =
  ## Encodes a sequence of 0s and 1s into tightly packed bytes
  ## Used in encoding key path of a KV-NODE
  let
    padding = repeat('0', (4 - bin.len) mod 4)
    padded_bin_len = bin.len + padding.len
    prefix = TWO_BITS[bin.len mod 4]

  if padded_bin_len mod 8 == 4:
    let prefixVal = PREFIX_00 & prefix & padding
    return decode_from_bin(concat(prefixVal, bin))
  else:
    let prefixVal = PREFIX_100000 & prefix & padding
    return decode_from_bin(concat(prefixVal, bin))

proc cmp[T](a: BytesRange, b: T): bool =
  if a.len != b.len: return false
  for i in 0..<a.len:
    if a[i].byte != b[i].byte: return false
  true

proc index[T](a: openArray[T], b: BytesRange): int =
  result = -1
  for i in 0..<a.len:
    if cmp(b, a[i]): return i

func decode_to_bin_keypath*(path: BytesRange): BinVector =
  # Decodes bytes into a sequence of 0s and 1s
  # Used in decoding key path of a KV-NODE
  var path = encode_to_bin(path).BytesRange
  if path[0] == 1:
    path = path[4..^1]

  assert path[0..2].cmp(PREFIX_00)
  let padded_len = TWO_BITS.index(path[2..4])
  path[4+((4 - padded_len) mod 4)..^1].BinVector
