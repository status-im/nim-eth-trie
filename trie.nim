import
  rlp/types, nibbles, tables

type
  TrieDatabaseKey = object
    hash: KeccakHash
    usedBytes: uint8

  TrieDatabase = concept type DB
    put(var DB, BytesRange, BytesRange) is bool
    del(var DB, BytesRange) is bool
    get(DB, BytesRange) is Bytes

  MemDB = table[Bytes, Bytes]

  TrieHash = BytesRange

  Trie = object
    db: ref MemDB
    rootHash*: TrieHash

  TrieNode = Rlp

  CorruptedTrieError* = object of Exception

const
  BLANK_STRING_HASH = hashFromHex "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
  BLANK_RLP_HASH    = hashFromHex "56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"

var
  emptySeq = Bytes(@[])
  emptyRange = initBytesRange(emptySeq)

proc initTrie*(): Trie =
  result.db = newTable[Bytes, Bytes]()
  result.rootHash = initBytesRange(@(BLANK_RLP_HASH.data))

proc getAux(db: MemDB, node: BytesRange, path: NibbleRange): BytesRange =
  if path.len == 0: return node
  if node.len == 0: return emptyRange

  let nodeRlp = rlpFromBytes(if node.len < 32: node else: db.get(node))

  case nodeRlp.listLen
  of 2:
    let (isLeaf, k) = hexPrefixDecode nodeRlp.toBytes
    nodeRlp.shift
    let v = nodeRlp.toBytes

    if path.startsWith(k):
      return getAux(db, v, path.slice(k.len))
    else:
      return emptyRange
  of 17:
    return getAux(db, nodeRlp.listItem(path[0]), path.slice(1))
  else:
    raise newException(CorruptedTrieError, "Trie node with an unexpected numbef or children")

proc get*(t: Trie, key: BytesRange): BytesRange =
  return getAux(t.db, t.rootHash, initNibbleRange(key))

proc dbDel(t: var Trie, data: BytesRange) =
  if key.len > 32: t.db.del(data.keccak)

proc dbDelHash(t: var Trie, hash: TrieHash) =
  if key.len > 32: t.db.del(hash)

proc dbPut(db: var MemDB, data: BytesRange): TrieHash =
  result = data.keccak
  db.put(result, data)

proc dbSaveRlp(db: var MemDB, node: Rlp): TrieHash =
  result = if node.rawData.len > 32: db.dbPut(node.rawData)
           else: node.rawData

proc isTrieBranch(rlp: Rlp): bool =
  rlp.isList and (var len = rlp.listLen; len == 2 or len == 17)

proc place(t: var Trie, data: Rlp,
           key: NibbleRange, value: BytesRange): BytesRange =
  t.dbDel(data)
  if data.isEmpty:
    return makeRlpList(hexPrefixEncode(key, true), value)

  assert data.isTrieBranch
  if data.listLen == 2:
    return makeRlpList(data.listItem(0), value)

  var r = initRlpStream(17)
  # XXX: This can be optmized to a direct bitwise copy of the source RLP
  for elem in data: r.append(elem)
  r.append value

  return r.finish()

proc toHash(r: Rlp): TrieHash =
  # XXX: validate the run-time type
  return r.toBytes

proc mergeAt(t: var Trie, orig: Rlp, origHash: TrieHash,
             key: NibbleRange, value: BytesRange,
             isInline = false): BytesRange

proc mergeAtAux(t: var Trie, output: RlpStream, orig: Rlp,
                key: NibbleRange, value: BytesRange) =
  var resolved = orig
  var isRemovable = false
  if not (orig.isList or orig.isEmpty):
    resolved = rlpFromBytes db.get(orig.toHash)
    isRemovable = true

  let b = t.mergeAt(origCopy, key, value, not isRemovable)
  output.append t.db.dbSaveRlp(b)

proc mergeAt(t: var Trie, orig: Rlp, origHash: TrieHash,
             key: NibbleRange, value: BytesRange,
             isInline = false): BytesRange =
  if orig.isEmpty:
    return place(t, orig, key, value)

  assert orig.isTrieBranch
  let len = orig.listLen
  if len == 2:
    let (isLeaf, k) = hexPrefixDecode orig.listItem(0).toBytes
    var origValue = orig.listItem(1)

    if k == key and isLeaf:
      return place(orig, key, value)

    let sharedNibbles = sharedPrefixLen(key, k)

    if sharedNibbles == k.len and not isLeaf:
      var r = initRlpStream(2)
      r.append orig.listItem(0)
      mergeAtAux(r, origValue, key.slice(k.len), value)
      return r.finish()

    t.db.dbDel orig.rawData
    if sharedNibbles > 0:
      # Split the extension node
      var bottom = initRlpStream(2)
      bottom.append hexPrefixEncode(k.slice(sharedNibbles), isLeaf)
      bottom.append origValue

      var top = initRlpStream(2)
      top.append hexPrefixEncode(k.slice(0, sharedNibbles), false)
      top.append t.db.dbSaveRlp(bottom.finish())

      return mergeAt(rlpFromBytes(top.finish()), key, value, true)
    else:
      # Create a branch node
      var branches = initRlpStream(17)
      if k.len == 0:
        # The key is now exhausted. This must be a leaf node
        assert isLeaf
        for i in 0 ..< 16:
          branches.append ""
        braches.append origValue

      else:
        let n = k[0]
        for i in 0 ..< 16:
          if i == n:
            if isLeaf or k.len > 1:
              let childNode = makeRlpList(hexPrefixEncode(k.slice(1), isLeaf), origValue)
              branches.append t.db.dbSaveRlp(childNode)
          else:
            branches.append ""
        branches.append ""

      return mergeAt(rlpFromBytes(branches.finish()), key, value, true)

  else:
    if key.len == 0:
      return t.place(orig, key, value)

    if isInline:
      t.db.del(origHash)

    let n = key[0]
    var i = 0
    var r = initRlpStream(17)

    for elem in orig:
      if i == n:
        t.mergeAtAux(r, elem, k.slice(1), value)
      else:
        r.append(elem)
      inc i

    return r.finish()

proc put*(t: var Trie, key, value: BytesRange) =
  let rootBytes = t.db.get(t.rootHash)
  assert rootBytes.len > 0

  let b = mergeAt(t, rlpFromBytes(rootBytes), t.rootHash,
                  initNibbleRange(key), value)

  if rootBytes.len < 32:
    t.db.del(t.rootHash)

  t.rootHash = t.db.dbPut(b)

