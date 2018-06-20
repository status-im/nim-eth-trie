import ranges/typedranges, rlp/types, ranges/ptr_arith

type
  BitVector*[T] = object
    data: Range[T]
    start: int
    mLen: int

const
  binaryZero* = false
  binaryOne* = true

template toBitVector*(x: BitVector): BitVector = x

proc toBitVector*[T](a: seq[T] | Range[T]): BitVector[T] =
  result.data  = toRange(a)
  result.start = 0
  result.mLen  = a.len * sizeof(T) * 8

proc toBitVector*[T](a: seq[T] | Range[T], len: int): BitVector[T] =
  assert(len <= sizeof(T) * 8 * a.len)
  result.data  = toRange(a)
  result.start = 0
  result.mLen  = len

proc toBitVector*[T](a: seq[T] | Range[T], start, len: int): BitVector[T] =
  assert(start <= len)
  assert(len <= sizeof(T) * 8 * a.len)
  result.data  = toRange(a)
  result.start = start
  result.mLen  = len

proc len*(r: BitVector): int {.inline.} = r.mLen

func calcBinShift(x: int): int {.compileTime.} =
  var z = 0
  var y = 0
  while true:
    if y == x: return z
    y = (y shl 1) or 0x01
    inc z

template getBit(T: typedesc, bits, p: untyped): untyped =
  const
    bitMask = sizeof(T) * 8 - 1
    binShift = calcBinShift(bitMask)
  ((int(bits[p shr binShift]) shr (bitMask - (p and bitMask))) and 0x01)

iterator bits[T](x: BitVector[T]): (int, bool) =
  var p = x.start
  var i = 0
  let e = x.len
  while i != e:
    yield (i, getBit(T, x.data, p) != 0)
    inc p
    inc i

iterator items*(x: BitVector): bool =
  for _, v in bits(x): yield v

iterator pairs*(x: BitVector): (int, bool) =
  for i, v in bits(x): yield (i, v)

proc `[]`*[T](x: BitVector[T], idx: int): bool {.inline.} =
  assert(idx < x.len)
  let p = x.start + idx
  result = getBit(T, x.data, p) != 0

template `^^`(s, i: untyped): untyped =
  (when i is BackwardsIndex: s.len - int(i) else: int(i))

proc sliceNormalized(x: BitVector, ibegin, iend: int): BitVector =
  assert(ibegin >= 0 and ibegin < x.len and iend >= ibegin and iend < x.len)
  result.data  = x.data
  result.start = x.start + ibegin
  result.mLen  = iend - ibegin + 1

proc `[]`*[U, V](r: BitVector, s: HSlice[U, V]): BitVector {.inline.} =
  sliceNormalized(r, r ^^ s.a, r ^^ s.b)

proc `==`*(a, b: BitVector): bool =
  if a.len != b.len: return false
  for i in 0..<a.len:
    if a[i] != b[i]: return false
  true

proc `[]=`*[T](x: BitVector[T], idx: int, val: bool) {.inline.} =
  assert(idx < x.len)

  const
    bitMask = sizeof(T) * 8 - 1
    binShift = calcBinShift(bitMask)

  var start = x.data.baseAddr
  let p = start.shift(idx shr binShift)
  let dist = bitMask - (idx and bitMask)
  # sigh, complicated
  p[] = p[] and (not T(0x01) shl dist)
  p[] = p[] or (T(val) shl dist)

proc setBit[T](x: BitVector[T], idx: int, val: bool) {.inline.} =
  # assume the destination bit is already zeroed
  assert(idx < x.len)

  const
    bitMask = sizeof(T) * 8 - 1
    binShift = calcBinShift(bitMask)

  var start = x.data.baseAddr
  let p = start.shift(idx shr binShift)
  p[] = p[] or (T(val) shl (bitMask - (idx and bitMask)))

proc `&`*[T](a, b: BitVector[T]): BitVector[T] =
  const
    bitMask = sizeof(T) * 8 - 1
    binShift = calcBinShift(bitMask)

  let len = (((a.len + b.len) + bitMask) and (not bitMask)) shr binShift
  result = toBitVector(newSeq[T](len), 0, a.len + b.len)

  for i in 0..<a.len: result.setBit(i, a[i])
  for i in 0..<b.len: result.setBit(i + a.len, b[i])

proc `$`*(x: BitVector): string =
  result = newStringOfCap(x.len)
  for b in x:
    result.add(if b: '1' else: '0')

proc getBits*[T](x: BitVector[T], offset, num: int): T =
  assert(num <= sizeof(T) * 8)
  for i in 0..<num:
    result = (result shl 1) or T(x[offset + i])
