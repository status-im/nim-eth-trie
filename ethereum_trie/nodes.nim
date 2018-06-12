import
  rlp/types as rlpTypes, utils/binaries, types, sequtils

type
  TrieNodeKind* = enum
    KV_TYPE = 0
    BRANCH_TYPE = 1
    LEAF_TYPE = 2

  TrieNode* = object
    case kind*: TrieNodeKind
    of KV_TYPE:
      keyPath*: BytesRange
      child*: BytesRange
    of BRANCH_TYPE:
      leftChild*: BytesRange
      rightChild*: BytesRange
    of LEAF_TYPE:
      value*: BytesRange

  InvalidNode* = object of Exception
  ValidationError* = object of Exception

proc parseNode*(node: BytesRange): TrieNode =
  # Input: a serialized node

  if node.len == 0:
    raise newException(InvalidNode, "Blank node is not a valid node type in Binary Trie")

  if node[0].ord < low(TrieNodeKind).ord or node[0].ord > high(TrieNodeKind).ord:
    raise newException(InvalidNode, "Invalid node type")

  let nodeType = node[0].TrieNodeKind
  case nodeType
  of BRANCH_TYPE:
    if node.len != 65:
      raise newException(InvalidNode, "Invalid branch node, both child node should be 32 bytes long each")
    # Output: node type, left child, right child
    result = TrieNode(kind: BRANCH_TYPE, leftChild: node[1..<33], rightChild: node[33..^1])
    assert(result.leftChild.len == 32)
    assert(result.rightChild.len == 32)
    return result
  of KV_TYPE:
    if node.len <= 33:
      raise newException(InvalidNode, "Invalid kv node, short of key path or child node hash")
    # Output: node type, keypath, child
    return TrieNode(kind: KV_TYPE, keyPath: decodeToBinKeypath(node[1..^33]).toRange, child: node[^32..^1])
  of LEAF_TYPE:
    if node.len == 1:
      raise newException(InvalidNode, "Invalid leaf node, can not contain empty value")
    # Output: node type, value
    return TrieNode(kind: LEAF_TYPE, value: node[1..^1])
  else:
    raise newException(InvalidNode, "Unable to parse node")

proc encodeKVNode*(keyPath, childNodeHash: BytesRange | Bytes): Bytes =
  ## Serializes a key/value node

  if keyPath.len == 0:
    raise newException(ValidationError, "Key path can not be empty")
  assert(childNodeHash.len == 32)

  let encodedKey = encodeFromBinKeypath(keyPath.toRange)
  result = @[KV_TYPE.byte].concat(encodedKey, childNodeHash)

proc encodeBranchNode*(leftChildNodeHash, rightChildNodeHash: BytesRange | Bytes): Bytes =
  ## Serializes a branch node

  assert(leftChildNodeHash.len == 32)
  assert(rightChildNodeHash.len == 32)
  result = @[BRANCH_TYPE.byte].concat(leftChildNodeHash, rightChildNodeHash)

proc encodeLeafNode*(value: BytesRange | Bytes): Bytes =
  ## Serializes a leaf node

  if value.len == 0:
    raise newException(ValidationError, "Value of leaf node can not be empty")
  result = @[LEAF_TYPE.byte].concat(value)

proc getCommonPrefixLength*(a, b: BytesRange): int =
  let len = min(a.len, b.len)
  for i in 0..<len:
    if a[i] != b[i]: return i
  result = len
