import
  rlp/types as rlpTypes

proc toBytesRange*(str: string): BytesRange =
  var s = newSeq[byte](str.len)
  for i in 0 ..< str.len:
    s[i] = byte(str[i])
  result = toRange(s)

proc `==`*(a, b: BytesRange): bool =
  if a.len != b.len: return false
  for i in 0..<a.len:
    if a[i] != b[i]: return false
  result = true
