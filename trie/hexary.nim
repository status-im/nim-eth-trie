import
  tables, itertools, rlp, trie.constants, trie.exceptions, trie.validation,
  trie.utils.sha3, trie.utils.nibbles, trie.utils.nodes

type
  DB = object

  HexaryTrie* = object
    db*: DB
    rootHash*: string

proc makeHexaryTrie*(db: [dict, T0, T1]; rootHash: string): HexaryTrie =
  result.db = db
  result.rootHash = rootHash

proc get*(self: HexaryTrie; key: string): string =
  validateIsBytes(key)
  var trieKey = bytesToNibbles(key)
  var rootNode = self._getNode(self.rootHash)
  return self._get(rootNode, trieKey)

proc _get*(self: HexaryTrie; node: seq[string]; trieKey: seq[int]): string =
  var nodeType = getNodeType(node)
  if nodeType == NODETYPE_BLANK:
    return BLANKNODE
  elif nodeType in :
    return self._getKvNode(node, trieKey)
  elif nodeType == NODETYPE_BRANCH:
    return self._getBranchNode(node, trieKey)
  else:
    raise Exception("Invariant: This shouldn\'t ever happen")
  
proc getFromProof*(cls: typedesc; rootHash: string; key: string; proof: (
    seq[string], seq[string], seq[string], seq[string], seq[string],
    seq[string], seq[string], seq[string])): string =
  var trie = cls({:}.toTable())
  for node in proof:
    trie._persistNode(node)
  trie.rootHash = rootHash
  try:
    return trie.get(key)
  except KeyError:
    raise newException(BadTrieProof, "Missing proof node with hash {}".format(
        getCurrentExceptionMsg().args))

proc getFromProof*(cls: typedesc; rootHash: string; key: string; proof: (
    seq[string], seq[string], seq[string], seq[string], seq[string],
    seq[string], seq[string])): Any =
  var trie = cls({:}.toTable())
  for node in proof:
    trie._persistNode(node)
  trie.rootHash = rootHash
  try:
    return trie.get(key)
  except KeyError:
    raise newException(BadTrieProof, "Missing proof node with hash {}".format(
        getCurrentExceptionMsg().args))

proc getFromProof*(cls: typedesc; rootHash: string; key: string; proof: [list, T0]): Any =
  var trie = cls({:}.toTable())
  for node in proof:
    trie._persistNode(node)
  trie.rootHash = rootHash
  try:
    return trie.get(key)
  except KeyError:
    raise newException(BadTrieProof, "Missing proof node with hash {}".format(
        getCurrentExceptionMsg().args))

proc _getNode*(self: HexaryTrie; nodeHash: string): seq[string] =
  if nodeHash == BLANKNODE:
    return BLANKNODE
  elif nodeHash == BLANKNODE_HASH:
    return BLANKNODE
  if len(nodeHash) < 32:
    var encodedNode = nodeHash
  else:
    encodedNode = self.db[nodeHash]
  var node = self._decodeNode(encodedNode)
  return node

proc _persistNode*(self: HexaryTrie; node: seq[string]): string =
  if isBlankNode(node):
    return BLANKNODE
  var encodedNode = rlp.encode(node)
  if len(encodedNode) < 32:
    return node
  var encodedNodeHash = keccak(encodedNode)
  self.db[encodedNodeHash] = encodedNode
  return encodedNodeHash

proc _decodeNode*(self: HexaryTrie; encodedNodeOrHash: string): seq[string] =
  if encodedNodeOrHash == BLANKNODE:
    return BLANKNODE
  elif isinstance(encodedNodeOrHash, list):
    return encodedNodeOrHash
  else:
    return rlp.decode(encodedNodeOrHash)
  
proc _getBranchNode*(self: HexaryTrie; node: seq[string]; trieKey: seq[int]): string =
  if nil:
    return node[16]
  else:
    subNode = self._getNode(node[trieKey[0]])
    return self._get(subNode, trieKey[1 ..< nil])

proc _getKvNode*(self: HexaryTrie; node: seq[string]; trieKey: seq[int]): string =
  var currentKey = extractKey(node)
  var nodeType = getNodeType(node)
  if nodeType == NODETYPE_LEAF:
    if trieKey == currentKey:
      return node[1]
    else:
      return BLANKNODE
  elif nodeType == NODETYPE_EXTENSION:
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

