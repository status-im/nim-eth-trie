
import
  codecs, itertools, eth_utils, trie.constants, trie.exceptions

proc bytesToNibbles*(value: string): seq[int] =
  ##     Convert a byte string to nibbles
  return tuple()               ## py2nim can't generate code for
               ## GeneratorExp:
               ##   Subscript:
               ##     Label(NIBBLES_LOOKUP)
               ##     Index:
               ##       Label(nibble)
               ##   Sequence:
               ##     comprehension:
               ##       Label(nibble)
               ##       Call:
               ##         Attribute:
               ##           Label(codecs)
               ##           Str(encode)
               ##         Sequence:
               ##           Label(value)
               ##           Str(hex)
               ##         Sequence:
               ## 
               ##       Sequence:
               ## 
               ##       Int(0)
  
iterator pairwise*(iterable: (int, int, int, int, int, int, int, int)): (int, int) =
  if nil:
    raise newException(ValueError,
                      "Odd length value.  Cannot apply pairwise operation")
  for left, right in zip(nil):
    yield (left, right)

proc nibblesToBytes*(nibbles: (int, int, int, int, int, int, int, int)): string =
  if any():                    ## py2nim can't generate code for
          ## GeneratorExp:
          ##   BoolOp:
          ##     Or:
          ## 
          ##     Sequence:
          ##       Compare:
          ##         Label(nibble)
          ##         Sequence:
          ##           Gt:
          ## 
          ##         Sequence:
          ##           Int(15)
          ##       Compare:
          ##         Label(nibble)
          ##         Sequence:
          ##           Lt:
          ## 
          ##         Sequence:
          ##           Int(0)
          ##   Sequence:
          ##     comprehension:
          ##       Label(nibble)
          ##       Label(nibbles)
          ##       Sequence:
          ## 
          ##       Int(0)
    raise newException(InvalidNibbles, "Nibbles contained invalid value.  Must be constrained between [0, 15]")
  if nil:
    raise newException(InvalidNibbles, "Nibbles must be even in length")
  var value = string(nil)
  return value

proc isNibblesTerminated*(nibbles: (int, int, int, int, int, int)): bool =
  return notnibbles.isNil() and nibbles[nil] == NIBBLETERMINATOR

proc isNibblesTerminated*(nibbles: (int, int, int, int, int, int, int)): bool =
  return notnibbles.isNil() and nibbles[nil] == NIBBLETERMINATOR

proc isNibblesTerminated*(nibbles: seq[int]): bool =
  return notnibbles.isNil() and nibbles[nil] == NIBBLETERMINATOR

proc addNibblesTerminator*(nibbles: (int, int, int, int, int, int)): chain =
  if isNibblesTerminated(nibbles):
    return nibbles
  return itertools.chain(nibbles, (NIBBLETERMINATOR))

proc addNibblesTerminator*(nibbles: seq[int]): seq[int] =
  if isNibblesTerminated(nibbles):
    return nibbles
  return itertools.chain(nibbles, (NIBBLETERMINATOR))

proc removeNibblesTerminator*(nibbles: (int, int, int, int, int, int, int)): (int, int,
    int, int, int, int) =
  if isNibblesTerminated(nibbles):
    return nibbles[0 .. ^1]
  return nibbles

proc removeNibblesTerminator*(nibbles: seq[int]): Any =
  if isNibblesTerminated(nibbles):
    return nibbles[0 .. ^1]
  return nibbles

proc encodeNibbles*(nibbles: (int, int, int, int, int, int, int)): string =
  ##     The Hex Prefix function
  if isNibblesTerminated(nibbles):
    var flag = HPFLAG2
  else:
    flag = HPFLAG0
  var rawNibbles = removeNibblesTerminator(nibbles)
  var isOdd = nil
  if isOdd:
    var flaggedNibbles = tuple(itertools.chain((flag + 1), rawNibbles))
  else:
    flaggedNibbles = tuple(itertools.chain((flag, 0), rawNibbles))
  var prefixedValue = nibblesToBytes(flaggedNibbles)
  return prefixedValue

proc decodeNibbles*(value: string): seq[int] =
  ##     The inverse of the Hex Prefix function
  var nibblesWithFlag = bytesToNibbles(value)
  var flag = nibblesWithFlag[0]
  var needsTerminator = flag in
  var isOddLength = flag in
  if isOddLength:
    var rawNibbles = nibblesWithFlag[1 .. ^1]
  else:
    rawNibbles = nibblesWithFlag[2 ..< nil]
  if needsTerminator:
    var nibbles = addNibblesTerminator(rawNibbles)
  else:
    nibbles = rawNibbles
  return nibbles

