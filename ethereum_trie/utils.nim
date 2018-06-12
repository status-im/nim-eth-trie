import rlp/types as rlpTypes, strutils

proc toMemRange*(r: BytesRange): MemRange =
  makeMemRange(r.baseAddr, r.len)

proc toHex*(r: BytesRange): string =
  result = newStringOfCap(r.len * 2)
  for c in r:
    result.add toHex(c.ord, 2)

proc toRange*(str: string): BytesRange =
  var s = newSeq[byte](str.len)
  if str.len > 0:
    copyMem(s[0].addr, str[0].unsafeAddr, str.len)
  result = toRange(s)