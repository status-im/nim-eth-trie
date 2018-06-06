import
  rlp/types as rlpTypes, utils/binaries

type
  TrieNodeType* = enum
    KV_TYPE = 0
    BRANCH_TYPE = 1
    LEAF_TYPE = 2

  InvalidNode* = object of Exception

const
  zeroBytesRange = Range[byte]()

proc parseNode(node: BytesRange): tuple[typ: TrieNodeType; leftChild, rightChild: BytesRange] =
  # Input: a serialized node

  if node.len == 0:
    raise newException(InvalidNode, "Blank node is not a valid node type in Binary Trie")

  let nodeType = node[0].TrieNodeType
  case nodeType
  of BRANCH_TYPE:
    if node.len != 65:
      raise newException(InvalidNode, "Invalid branch node, both child node should be 32 bytes long each")
    # Output: node type, left child, right child
    let ret = (BRANCH_TYPE, node[1..33], node[33..^1])
    assert(ret[1].len == 32)
    assert(ret[2].len == 32)
    return ret
  of KV_TYPE:
    if node.len <= 33:
      raise newException(InvalidNode, "Invalid kv node, short of key path or child node hash")
    # Output: node type, keypath: child
    return (KV_TYPE, decodeToBinKeypath(node[1..^32]).BytesRange, node[^32..^1])
  of LEAF_TYPE:
    if node.len == 1:
      raise newException(InvalidNode, "Invalid leaf node, can not contain empty value")
    # Output: node type, None, value
    return (LEAF_TYPE, zeroBytesRange, node[1..^1])
  else:
    raise newException(InvalidNode, "Unable to parse node")
