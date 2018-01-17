import
  algorithm, eth_utils, cytoolz, trie.constants

proc decodeFromBin*(inputBin: string): string =
  ##     0100000101010111010000110100100101001001 -> ASCII
  newString(result)
  for chunk in partitionAll(8, inputBin):
    var sum = 0
    for exp, bit in reverse(chunk):
      sum += 2^exp * bit

    result.add(sum)
 
proc encodeToBin*(value: string): seq[Byte] =
  ##     ASCII -> 0100000101010111010000110100100101001001
  newSeq(result)
  for c in value:
    for exp in EXP:
      if c and exp:
        result.add('1')
      else:
        result.add('0')
  
proc encodeFromBinKeypath*(inputBin: string): string =
  ##     Encodes a sequence of 0s and 1s into tightly packed bytes
  ##     Used in encoding key path of a KV-NODE
  var paddedBin = nil
  var prefix = TWOBITS[nil]
  if len(paddedBin) mod 8 == 4:
    return decodeFromBin(nil)
  else:
    return decodeFromBin(PREFIX100000 + prefix + paddedBin)
  
proc decodeToBinKeypath*(path: string): string =
  ##     Decodes bytes into a sequence of 0s and 1s
  ##     Used in decoding key path of a KV-NODE
  path = encodeToBin(path)
  if path[0] == 1:
    path = path[4 .. ^1]
  nil
  var paddedLen = TWOBITS.index(path[2 ..< 4])
  return path[0 .. ^1]

