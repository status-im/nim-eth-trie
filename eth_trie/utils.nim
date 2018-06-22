import
  rlp/types as rlpTypes, strutils,
  nimcrypto/[hash, keccak], parseutils, types, binaries,
  ranges/ptr_arith

proc baseAddr*(x: Bytes): ptr byte = x[0].unsafeAddr

proc toTrieNodeKey*(hash: KeccakHash): TrieNodeKey =
  result = newRange[byte](32)
  copyMem(result.baseAddr, hash.data.baseAddr, 32)

proc toHash*(nodeHash: TrieNodeKey): KeccakHash =
  assert(nodeHash.len == 32)
  copyMem(result.data.baseAddr, nodeHash.baseAddr, 32)

template toRange*(hash: KeccakHash): BytesRange =
  toTrieNodeKey(hash)

proc toRange*(str: string): BytesRange =
  var s = newSeq[byte](str.len)
  if str.len > 0:
    copyMem(s[0].addr, str[0].unsafeAddr, str.len)
  result = toRange(s)

proc hashFromHex*(bits: static[int], input: string): MDigest[bits] =
  if input.len != bits div 4:
    raise newException(ValueError,
                       "The input string has incorrect size")

  for i in 0 ..< bits div 8:
    var nextByte: int
    if parseHex(input, nextByte, i*2, 2) == 2:
      result.data[i] = uint8(nextByte)
    else:
      raise newException(ValueError,
"The input string contains invalid characters")

template hashFromHex*(s: static[string]): untyped = hashFromHex(s.len * 4, s)

proc keccak*(input: BytesRange | Bytes, output: var MutRange[byte]) =
  var ctx: keccak256
  ctx.init()
  ctx.update(input.baseAddr, uint(input.len))
  ctx.finish output.toOpenArray
  ctx.clear()
