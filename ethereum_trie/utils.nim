import rlp/types as rlpTypes, strutils

proc toMemRange*(r: BytesRange): MemRange =
  makeMemRange(r.baseAddr, r.len)
  
proc toHex*(r: BytesRange): string =
  result = newStringOfCap(r.len * 2)
  for c in r:
    result.add toHex(c.ord, 2)
