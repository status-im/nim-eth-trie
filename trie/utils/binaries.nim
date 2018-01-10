
import
  algorithm, eth_utils, cytoolz, trie.constants

iterator decodeFromBin*(inputBin: cstring): int =
  ##     0100000101010111010000110100100101001001 -> ASCII
  for chunk in partitionAll(8, inputBin):
    yield sum()                ## py2nim can't generate code for
              ## GeneratorExp:
              ##   BinOp:
              ##     BinOp:
              ##       Int(2)
              ##       Pow:
              ## 
              ##       Label(exp)
              ##     Mult:
              ## 
              ##     Label(bit)
              ##   Sequence:
              ##     comprehension:
              ##       Tuple:
              ##         Label(exp)
              ##         Label(bit)
              ##       Call:
              ##         Label(enumerate)
              ##         Sequence:
              ##           Call:
              ##             Label(reversed)
              ##             Sequence:
              ##               Label(chunk)
              ##             Sequence:
              ## 
              ##         Sequence:
              ## 
              ##       Sequence:
              ## 
              ##       Int(0)
  
iterator encodeToBin*(value: cstring): bool =
  ##     ASCII -> 0100000101010111010000110100100101001001
  for char in value:
    for exp in EXP:
      if nil:
        yield true
      else:
        yield False
  
proc encodeFromBinKeypath*(inputBin: cstring): cstring =
  ##     Encodes a sequence of 0s and 1s into tightly packed bytes
  ##     Used in encoding key path of a KV-NODE
  var paddedBin = nil
  var prefix = TWOBITS[nil]
  if len(paddedBin) mod 8 == 4:
    return decodeFromBin(nil)
  else:
    return decodeFromBin(PREFIX100000 + prefix + paddedBin)
  
proc decodeToBinKeypath*(path: cstring): cstring =
  ##     Decodes bytes into a sequence of 0s and 1s
  ##     Used in decoding key path of a KV-NODE
  path = encodeToBin(path)
  if path[0] == 1:
    path = path[4 .. ^1]
  nil
  var paddedLen = TWOBITS.index(path[2 ..< 4])
  return path[0 .. ^1]

