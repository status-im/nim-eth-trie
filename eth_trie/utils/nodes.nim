import
  trie.constants, trie.exceptions, trie.utils.binaries, trie.validation, nibbles

proc getNodeType*(node: string): int =
  if node == BLANKNODE:
    return NODETYPE_BLANK
  elif len(node) == 2:
    (key, _) = node
    nibbles = decodeNibbles(key)
    if isNibblesTerminated(nibbles):
      return NODETYPE_LEAF
    else:
      return NODETYPE_EXTENSION
  elif len(node) == 17:
    return NODETYPE_BRANCH
  else:
    raise InvalidNode("Unable to determine node type")
  
proc getNodeType*(node: seq[string]): int =
  if node == BLANKNODE:
    return NODETYPE_BLANK
  elif len(node) == 2:
    (key, _) = node
    nibbles = decodeNibbles(key)
    if isNibblesTerminated(nibbles):
      return NODETYPE_LEAF
    else:
      return NODETYPE_EXTENSION
  elif len(node) == 17:
    return NODETYPE_BRANCH
  else:
    raise InvalidNode("Unable to determine node type")
  
proc isBlankNode*(node: seq[string]): bool =
  return node == BLANKNODE

proc extractKey*(node: seq[string]): seq[int] =
  (prefixedKey, _) = node
  var key = removeNibblesTerminator(decodeNibbles(prefixedKey))
  return key

proc computeLeafKey*(nibbles: (int, int, int, int, int, int)): string =
  return encodeNibbles(addNibblesTerminator(nibbles))

proc getCommonPrefixLength*(leftKey: string; rightKey: string): int =
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

proc encodeKvNode*(keypath: string; childNodeHash: string): string =
  ##     Serializes a key/value node
  if keypath is None or keypath == string"":
    raise newException(ValidationError, "Key path can not be empty")
  validateIsBytes(keypath)
  validateIsBytes(childNodeHash)
  validateLength(childNodeHash, 32)
  return nil

proc encodeKvNode*(keypath: string; childNodeHash: int): void =
  ##     Serializes a key/value node
  if keypath is None or keypath == string"":
    raise newException(ValidationError, "Key path can not be empty")
  validateIsBytes(keypath)
  validateIsBytes(childNodeHash)
  validateLength(childNodeHash, 32)
  return nil

proc encodeKvNode*(keypath: string; childNodeHash: range): void =
  ##     Serializes a key/value node
  if keypath is None or keypath == string"":
    raise newException(ValidationError, "Key path can not be empty")
  validateIsBytes(keypath)
  validateIsBytes(childNodeHash)
  validateLength(childNodeHash, 32)
  return nil

proc encodeBranchNode*(leftChildNodeHash: string; rightChildNodeHash: string): string =
  ##     Serializes a branch node
  validateIsBytes(leftChildNodeHash)
  validateLength(leftChildNodeHash, 32)
  validateIsBytes(rightChildNodeHash)
  validateLength(rightChildNodeHash, 32)
  return nil

proc encodeBranchNode*(leftChildNodeHash: string; rightChildNodeHash: int): void =
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

proc encodeLeafNode*(value: string): string =
  ##     Serializes a leaf node
  validateIsBytes(value)
  if value is None or value == string"":
    raise newException(ValidationError, "Value of leaf node can not be empty")
  return nil

proc encodeLeafNode*(value: int): void =
  ##     Serializes a leaf node
  validateIsBytes(value)
  if value is None or value == string"":
    raise newException(ValidationError, "Value of leaf node can not be empty")
  return nil

proc encodeLeafNode*(value: range): void =
  ##     Serializes a leaf node
  validateIsBytes(value)
  if value is None or value == string"":
    raise newException(ValidationError, "Value of leaf node can not be empty")
  return nil

