
import
  trie.constants, trie.exceptions, trie.utils.binaries, trie.validation, nibbles

proc getNodeType*(node: cstring): int =
  if node == BLANKNODE:
    return NODETYPEBLANK
  elif len(node) == 2:
    (key, _) = node
    nibbles = decodeNibbles(key)
    if isNibblesTerminated(nibbles):
      return NODETYPELEAF
    else:
      return NODETYPEEXTENSION
  elif len(node) == 17:
    return NODETYPEBRANCH
  else:
    raise InvalidNode("Unable to determine node type")
  
proc getNodeType*(node: seq[cstring]): int =
  if node == BLANKNODE:
    return NODETYPEBLANK
  elif len(node) == 2:
    (key, _) = node
    nibbles = decodeNibbles(key)
    if isNibblesTerminated(nibbles):
      return NODETYPELEAF
    else:
      return NODETYPEEXTENSION
  elif len(node) == 17:
    return NODETYPEBRANCH
  else:
    raise InvalidNode("Unable to determine node type")
  
proc isBlankNode*(node: seq[cstring]): bool =
  return node == BLANKNODE

proc extractKey*(node: seq[cstring]): seq[int] =
  (prefixedKey, _) = node
  var key = removeNibblesTerminator(decodeNibbles(prefixedKey))
  return key

proc computeLeafKey*(nibbles: (int, int, int, int, int, int)): cstring =
  return encodeNibbles(addNibblesTerminator(nibbles))

proc getCommonPrefixLength*(leftKey: cstring; rightKey: cstring): int =
  for idx, (leftNibble, rightNibble) in zip(leftKey, rightKey):
    if leftNibble != rightNibble:
      return idx
  return min(len(leftKey), len(rightKey))

proc getCommonPrefixLength*(leftKey: [list, T0]; rightKey: [list, T0]): Any =
  for idx, (leftNibble, rightNibble) in zip(leftKey, rightKey):
    if leftNibble != rightNibble:
      return idx
  return min(len(leftKey), len(rightKey))

proc getCommonPrefixLength*(leftKey: [list, T0]; rightKey: seq[int]): Any =
  for idx, (leftNibble, rightNibble) in zip(leftKey, rightKey):
    if leftNibble != rightNibble:
      return idx
  return min(len(leftKey), len(rightKey))

proc getCommonPrefixLength*(leftKey: seq[int]; rightKey: [list, T0]): Any =
  for idx, (leftNibble, rightNibble) in zip(leftKey, rightKey):
    if leftNibble != rightNibble:
      return idx
  return min(len(leftKey), len(rightKey))

proc getCommonPrefixLength*(leftKey: seq[int]; rightKey: seq[int]): Any =
  for idx, (leftNibble, rightNibble) in zip(leftKey, rightKey):
    if leftNibble != rightNibble:
      return idx
  return min(len(leftKey), len(rightKey))

proc consumeCommonPrefix*(leftKey: [list, T0]; rightKey: [list, T0]): ([list, T0],
    [list, T0], [list, T0]) =
  var
    commonPrefixLength = getCommonPrefixLength(leftKey, rightKey)
    commonPrefix = leftKey[0 ..< commonPrefixLength]
    leftRemainder = leftKey[commonPrefixLength .. ^1]
    rightRemainder = rightKey[commonPrefixLength .. ^1]
  return (commonPrefix, leftRemainder, rightRemainder)

proc consumeCommonPrefix*(leftKey: [list, T0]; rightKey: seq[int]): (Any, Any, Any) =
  var
    commonPrefixLength = getCommonPrefixLength(leftKey, rightKey)
    commonPrefix = leftKey[0 ..< commonPrefixLength]
    leftRemainder = leftKey[commonPrefixLength .. ^1]
    rightRemainder = rightKey[commonPrefixLength .. ^1]
  return (commonPrefix, leftRemainder, rightRemainder)

proc consumeCommonPrefix*(leftKey: seq[int]; rightKey: [list, T0]): (Any, Any, Any) =
  var
    commonPrefixLength = getCommonPrefixLength(leftKey, rightKey)
    commonPrefix = leftKey[0 ..< commonPrefixLength]
    leftRemainder = leftKey[commonPrefixLength .. ^1]
    rightRemainder = rightKey[commonPrefixLength .. ^1]
  return (commonPrefix, leftRemainder, rightRemainder)

proc consumeCommonPrefix*(leftKey: seq[int]; rightKey: seq[int]): (Any, Any, Any) =
  var
    commonPrefixLength = getCommonPrefixLength(leftKey, rightKey)
    commonPrefix = leftKey[0 ..< commonPrefixLength]
    leftRemainder = leftKey[commonPrefixLength .. ^1]
    rightRemainder = rightKey[commonPrefixLength .. ^1]
  return (commonPrefix, leftRemainder, rightRemainder)

proc encodeKvNode*(keypath: cstring; childNodeHash: cstring): cstring =
  ##     Serializes a key/value node
  if keypath is None or keypath == cstring"":
    raise newException(ValidationError, "Key path can not be empty")
  validateIsBytes(keypath)
  validateIsBytes(childNodeHash)
  validateLength(childNodeHash, 32)
  return nil

proc encodeKvNode*(keypath: cstring; childNodeHash: int): void =
  ##     Serializes a key/value node
  if keypath is None or keypath == cstring"":
    raise newException(ValidationError, "Key path can not be empty")
  validateIsBytes(keypath)
  validateIsBytes(childNodeHash)
  validateLength(childNodeHash, 32)
  return nil

proc encodeKvNode*(keypath: cstring; childNodeHash: range): void =
  ##     Serializes a key/value node
  if keypath is None or keypath == cstring"":
    raise newException(ValidationError, "Key path can not be empty")
  validateIsBytes(keypath)
  validateIsBytes(childNodeHash)
  validateLength(childNodeHash, 32)
  return nil

proc encodeBranchNode*(leftChildNodeHash: cstring; rightChildNodeHash: cstring): cstring =
  ##     Serializes a branch node
  validateIsBytes(leftChildNodeHash)
  validateLength(leftChildNodeHash, 32)
  validateIsBytes(rightChildNodeHash)
  validateLength(rightChildNodeHash, 32)
  return nil

proc encodeBranchNode*(leftChildNodeHash: cstring; rightChildNodeHash: int): void =
  ##     Serializes a branch node
  validateIsBytes(leftChildNodeHash)
  validateLength(leftChildNodeHash, 32)
  validateIsBytes(rightChildNodeHash)
  validateLength(rightChildNodeHash, 32)
  return nil

proc encodeBranchNode*(leftChildNodeHash: seq[int]; rightChildNodeHash: seq[int]): void =
  ##     Serializes a branch node
  validateIsBytes(leftChildNodeHash)
  validateLength(leftChildNodeHash, 32)
  validateIsBytes(rightChildNodeHash)
  validateLength(rightChildNodeHash, 32)
  return nil

proc encodeLeafNode*(value: cstring): cstring =
  ##     Serializes a leaf node
  validateIsBytes(value)
  if value is None or value == cstring"":
    raise newException(ValidationError, "Value of leaf node can not be empty")
  return nil

proc encodeLeafNode*(value: int): void =
  ##     Serializes a leaf node
  validateIsBytes(value)
  if value is None or value == cstring"":
    raise newException(ValidationError, "Value of leaf node can not be empty")
  return nil

proc encodeLeafNode*(value: range): void =
  ##     Serializes a leaf node
  validateIsBytes(value)
  if value is None or value == cstring"":
    raise newException(ValidationError, "Value of leaf node can not be empty")
  return nil

