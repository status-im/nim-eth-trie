
import
  tables, itertools, rlp, trie.constants, trie.exceptions, trie.validation,
  trie.utils.sha3, trie.utils.nibbles, trie.utils.nodes

type
  HexaryTrie* = object of object
    db*: void
    rootHash*: cstring
    BLANKNODE*: Any
    BLANKNODEHASH*: Any

method makeHexaryTrie*(db: [dict, T0, T1]; rootHash: cstring): HexaryTrie =
  result.db = nil
  result.rootHash = nil
  result.BLANKNODEHASH = BLANKNODEHASH
  result.BLANKNODE = BLANKNODE
  result.db = db
  validateIsBytes(rootHash)
  result.rootHash = rootHash

method get*(self: HexaryTrie; key: cstring): cstring =
  validateIsBytes(key)
  var trieKey = bytesToNibbles(key)
  var rootNode = self._getNode(self.rootHash)
  return self._get(rootNode, trieKey)

method _get*(self: HexaryTrie; node: seq[cstring]; trieKey: seq[int]): cstring =
  var nodeType = getNodeType(node)
  if nodeType == NODETYPEBLANK:
    return BLANKNODE
  elif nodeType in :
    return self._getKvNode(node, trieKey)
  elif nodeType == NODETYPEBRANCH:
    return self._getBranchNode(node, trieKey)
  else:
    raise Exception("Invariant: This shouldn\'t ever happen")
  
method getFromProof*(cls: typedesc; rootHash: cstring; key: cstring; proof: (
    seq[cstring], seq[cstring], seq[cstring], seq[cstring], seq[cstring],
    seq[cstring], seq[cstring], seq[cstring])): cstring =
  var trie = cls({:}.toTable())
  for node in proof:
    trie._persistNode(node)
  trie.rootHash = rootHash
  try:
    return trie.get(key)
  except KeyError:
    raise newException(BadTrieProof, "Missing proof node with hash {}".format(
        getCurrentExceptionMsg().args))

method getFromProof*(cls: typedesc; rootHash: cstring; key: cstring; proof: (
    seq[cstring], seq[cstring], seq[cstring], seq[cstring], seq[cstring],
    seq[cstring], seq[cstring])): Any =
  var trie = cls({:}.toTable())
  for node in proof:
    trie._persistNode(node)
  trie.rootHash = rootHash
  try:
    return trie.get(key)
  except KeyError:
    raise newException(BadTrieProof, "Missing proof node with hash {}".format(
        getCurrentExceptionMsg().args))

method getFromProof*(cls: typedesc; rootHash: cstring; key: cstring; proof: [list, T0]): Any =
  var trie = cls({:}.toTable())
  for node in proof:
    trie._persistNode(node)
  trie.rootHash = rootHash
  try:
    return trie.get(key)
  except KeyError:
    raise newException(BadTrieProof, "Missing proof node with hash {}".format(
        getCurrentExceptionMsg().args))

method _getNode*(self: HexaryTrie; nodeHash: cstring): seq[cstring] =
  if nodeHash == BLANKNODE:
    return BLANKNODE
  elif nodeHash == BLANKNODEHASH:
    return BLANKNODE
  if len(nodeHash) < 32:
    var encodedNode = nodeHash
  else:
    encodedNode = self.db[nodeHash]
  var node = self._decodeNode(encodedNode)
  return node

method _persistNode*(self: HexaryTrie; node: seq[cstring]): cstring =
  validateIsNode(node)
  if isBlankNode(node):
    return BLANKNODE
  var encodedNode = rlp.encode(node)
  if len(encodedNode) < 32:
    return node
  var encodedNodeHash = keccak(encodedNode)
  self.db[encodedNodeHash] = encodedNode
  return encodedNodeHash

method _decodeNode*(self: HexaryTrie; encodedNodeOrHash: cstring): seq[cstring] =
  if encodedNodeOrHash == BLANKNODE:
    return BLANKNODE
  elif isinstance(encodedNodeOrHash, list):
    return encodedNodeOrHash
  else:
    return rlp.decode(encodedNodeOrHash)
  
method _getBranchNode*(self: HexaryTrie; node: seq[cstring]; trieKey: seq[int]): cstring =
  if nil:
    return node[16]
  else:
    subNode = self._getNode(node[trieKey[0]])
    return self._get(subNode, trieKey[1 ..< nil])

method _getKvNode*(self: HexaryTrie; node: seq[cstring]; trieKey: seq[int]): cstring =
  var currentKey = extractKey(node)
  var nodeType = getNodeType(node)
  if nodeType == NODETYPELEAF:
    if trieKey == currentKey:
      return node[1]
    else:
      return BLANKNODE
  elif nodeType == NODETYPEEXTENSION:
    if keyStartsWith(trieKey, currentKey):
      subNode = self._getNode(node[1])
      return self._get(subNode, trieKey[len(currentKey) ..< nil])
    else:
      return BLANKNODE
  else:
    raise Exception("Invariant: unreachable code path")
  
proc makeHexaryTrie*(): HexaryTrie =
  result.db = nil
  result.rootHash = nil
  result.BLANKNODEHASH = BLANKNODEHASH
  result.BLANKNODE = BLANKNODE

