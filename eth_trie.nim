import
  tables, ranges/ptr_arith, keccak_tiny,
  rlp, eth_trie/[nibbles, types]

export
  types

type
  TrieNodeKey = object
    hash: KeccakHash
    usedBytes: uint8

  Trie[DB: TrieDatabase] = object
    dbLink: ref DB
    rootHash: TrieNodeKey

  TrieNode = Rlp

  CorruptedTrieError* = object of Exception

var
  BLANK_STRING_HASH = hashFromHex("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
  BLANK_RLP_HASH    = hashFromHex("56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421")

proc toMemRange*(r: BytesRange): MemRange =
  makeMemRange(r.bytes.baseAddr.shift(r.ibegin), r.len)

proc keccak*(r: BytesRange): KeccakHash =
  keccak_256(r)

converter toTrieNodeKey(hash: KeccakHash): TrieNodeKey =
  result.hash = hash
  result.usedBytes = 32

proc initTrie*[DB](db: ref DB): Trie[DB] =
  result.dbLink = db
  result.rootHash = BLANK_RLP_HASH.toTrieNodeKey

{.this: self.}
{.experimental.}

using
  self: var Trie
  db: TrieDatabase
  node, hash: TrieNodeKey
  key: BytesRange
  path: NibblesRange
  rlpWriter: var RlpWriter
  origRlp: Rlp

template db(t: Trie): untyped = t.dbLink[]

proc rootHashHex*(t: Trie): string =
  $t.rootHash.hash

proc getAux(db: TrieDatabase, node: TrieNodeKey, path: NibblesRange): BytesRange =
  if path.len == 0: return node
  if node.len == 0: return zeroBytesRange

  let nodeRlp = rlpFromBytes(if node.len < 32: node else: db.get(node))

  case nodeRlp.listLen
  of 2:
    let (isLeaf, k) = hexPrefixDecode nodeRlp.toBytes
    nodeRlp.shift
    let v = nodeRlp.toBytes

    if path.startsWith(k):
      return getAux(db, v, path.slice(k.len))
    else:
      return zeroBytesRange
  of 17:
    return getAux(db, nodeRlp.listElem(path[0]), path.slice(1))
  else:
    raise newException(CorruptedTrieError, "Trie node with an unexpected numbef or children")

proc get*(self; key): BytesRange =
  return getAux(self.db, self.rootHash, initNibbleRange(key))

proc dbDel(t: var Trie, data: BytesRange) =
  if data.len > 32: discard t.db.del(data.keccak)

proc dbPut(db: var TrieDatabase, data: BytesRange): TrieNodeKey =
  # result.hash = data.keccak
  # result.usedBytes = 32
  # db.put(result.hash, data)
  discard

proc dbSaveRlp(db: var TrieDatabase, data: BytesRange): TrieNodeKey =
  if data.len > 32:
    result = dbPut(db, data)
  else:
    result.usedBytes = uint8(data.len)
    copyMem(result.hash.data.baseAddr, data.rangeBeginAddr, data.len)

proc isTrieBranch(rlp: Rlp): bool =
  rlp.isList and (var len = rlp.listLen; len == 2 or len == 17)

proc place(self: var Trie, data: Rlp,
           key: NibblesRange, value: BytesRange): BytesRange =
  self.dbDel(data.rawData)
  if data.isEmpty:
    return encodeList(hexPrefixEncode(key, true), value)

  assert data.isTrieBranch
  if data.listLen == 2:
    return encodeList(data.listElem(0).rawData, value)

  var r = initRlpList(17)
  var dataCopy = data
  # XXX: This can be optmized to a direct bitwise copy of the source RLP
  for elem in rlp.items(dataCopy):
    r.append(elem.rawData)
  r.append value

  return r.finish()

proc toHash(r: Rlp): KeccakHash =
  let r = r.toBytes
  if r.len == 32:
    copyMem(result.data.baseAddr, r.rangeBeginAddr, 32)
  else:
    raise newException(BadCastError,
      "RLP expected to be a Keccak hash value, but has an incorrect length")

proc isTwoItemNode(self: Trie; r: Rlp): bool =
  mixin get

  if r.isBlob:
    let resolved = get(self.db, r.toHash).toRange
    let rlp = rlpFromBytes(resolved)
    return rlp.isList and rlp.listLen == 2
  else:
    return r.isList and r.listLen == 2

template append(rlpWriter: var RlpWriter; key: TrieNodeKey) =
  append(rlpWriter, makeMemRange(key.hash.data.baseAddr, csize(key.usedBytes)))

proc isLeaf(r: Rlp): bool =
  assert r.isList and r.listLen == 2
  let b = r.listElem(0).toBytes()
  return (b[0] and 0x20) != 0

proc findSingleChild(r: Rlp; childPos: var byte): Rlp =
  result = zeroBytesRlp
  var i: byte = 0
  var rlp = r
  for elem in rlp:
    if not elem.isEmpty:
      if not result.hasData:
        result = elem
        childPos = i
      else:
        return zeroBytesRlp
    inc i

proc deleteAt(self: var Trie; origRlp: Rlp, key: NibblesRange): BytesRange

proc deleteAux(self: var Trie; rlpWriter: var RlpWriter;
               origRlp: Rlp; path: NibblesRange): bool =
  mixin get

  let b = if origRlp.isEmpty: zeroBytesRange
          else: self.deleteAt(if origRlp.isList: origRlp else: rlpFromBytes(get(self.db, origRlp.toHash).toRange),
                              path)

  if b.len == 0:
    return false

  rlpWriter.append self.db.dbSaveRlp(b)
  return true

proc graft(self: var Trie; r: Rlp): BytesRange =
  mixin get

  assert r.isList and r.listLen == 2
  var (origIsLeaf, origPath) = hexPrefixDecode r.listElem(0).toBytes
  var value = r.listElem(1)

  var n: Rlp
  if not value.isList:
    let nodeKey = value.toHash
    var resolvedData = self.db.get(nodeKey).toRange
    discard self.db.del(nodeKey)
    value = rlpFromBytes resolvedData

  assert value.listLen == 2
  let (valueIsLeaf, valueKey) = hexPrefixDecode value.listElem(0).toBytes

  var rlpWriter = initRlpList(2)
  rlpWriter.append hexPrefixEncode(origPath, valueKey, valueIsLeaf)
  rlpWriter.append value.listElem(1)
  return rlpWriter.finish

proc mergeAndGraft(self: var Trie; soleChild: Rlp, childPos: byte): BytesRange =
  mixin append

  var output = initRlpList(2)
  if childPos == 16:
    output.append hexPrefixEncode(zeroNibblesRange, true)
  else:
    assert(not soleChild.isEmpty)
    output.append int(hexPrefixEncodeByte(childPos))
  output.append(soleChild)
  result = output.finish()
  
  if self.isTwoItemNode(soleChild):
    result = self.graft(rlpFromBytes(result))

proc deleteAt(self: var Trie; origRlp: Rlp, key: NibblesRange): BytesRange =
  if origRlp.isEmpty:
    return zeroBytesRange

  assert origRlp.isTrieBranch
  let origBytes = origRlp.toBytes
  if origRlp.listLen == 2:
    let (isLeaf, k) = hexPrefixDecode origBytes
    if k == key and isLeaf:
      self.dbDel origBytes
      return zeroBytesRange

    if key.startsWith(k):
      var
        rlpWriter = initRlpList(2)
        path = origRlp.listElem(0)
        value = origRlp.listElem(1)
      rlpWriter.append(path)
      if not self.deleteAux(rlpWriter, value, key.slice(k.len)):
        return zeroBytesRange
      self.dbDel origBytes
      var finalBytes = rlpWriter.finish
      var rlp = rlpFromBytes(finalBytes)
      if self.isTwoItemNode(rlp.listElem(1)):
        return self.graft(rlp)
      return finalBytes
    else:
      return zeroBytesRange
  else:
    if key.len == 0 and origRlp.listElem(16).isEmpty:
      self.dbDel origBytes
      var foundChildPos: byte
      let singleChild = origRlp.findSingleChild(foundChildPos)
      if singleChild.hasData and foundChildPos != 16:
        result = self.mergeAndGraft(singleChild, foundChildPos)
      else:
        var rlpRes = initRlpList(17)
        var origCopy = origRlp
        for elem in items(origCopy):
          rlpRes.append(elem)
        rlpRes.append ""
        return rlpRes.finish
    else:
      var rlpWriter = initRlpList(17)
      let keyHead = int(key[0])
      var i = 0
      var origCopy = origRlp
      for elem in items(origCopy):
        if i == keyHead:
          if not self.deleteAux(rlpWriter, elem, key.slice(1)):
            return zeroBytesRange
        else:
          rlpWriter.append(elem)
        inc i

      self.dbDel origBytes
      result = rlpWriter.finish
      var resultRlp = rlpFromBytes(result)
      var foundChildPos: byte
      let singleChild = resultRlp.findSingleChild(foundChildPos)
      if singleChild.hasData:
        result = self.mergeAndGraft(singleChild, foundChildPos)

proc del*(self: var Trie; key: BytesRange) =
  mixin get

  var
    rootBytes = get(self.db, self.rootHash.hash)
    rootRlp = rlpFromBytes rootBytes.toRange

  var newRootBytes = self.deleteAt(rootRlp, initNibbleRange(key))
  if newRootBytes.len > 0:
    if rootBytes.len < 32:
      discard self.db.del(self.rootHash.hash)
    assert newRootBytes.len >= 32
    self.rootHash = self.db.dbPut(newRootBytes)

proc mergeAt(self: var Trie, orig: Rlp, origHash: KeccakHash,
             key: NibblesRange, value: BytesRange,
             isInline = false): BytesRange

proc mergeAt(self: var Trie, rlp: Rlp,
             key: NibblesRange, value: BytesRange,
             isInline = false): BytesRange =
  self.mergeAt(rlp, rlp.rawData.keccak, key, value, isInline)

proc mergeAtAux(self: var Trie, output: var RlpWriter, orig: Rlp,
                key: NibblesRange, value: BytesRange) =
  mixin get

  var resolved = orig
  var isRemovable = false
  if not (orig.isList or orig.isEmpty):
    resolved = rlpFromBytes get(self.db, orig.toHash).toRange
    isRemovable = true

  let b = self.mergeAt(resolved, key, value, not isRemovable)
  output.append self.db.dbSaveRlp(b)

proc mergeAt(self: var Trie, orig: Rlp, origHash: KeccakHash,
             key: NibblesRange, value: BytesRange,
             isInline = false): BytesRange =
  if orig.isEmpty:
    return self.place(orig, key, value)

  assert orig.isTrieBranch
  if orig.listLen == 2:
    let (isLeaf, k) = hexPrefixDecode orig.listElem(0).toBytes
    var origValue = orig.listElem(1)

    if k == key and isLeaf:
      return self.place(orig, key, value)

    let sharedNibbles = sharedPrefixLen(key, k)

    if sharedNibbles == k.len and not isLeaf:
      var r = initRlpList(2)
      r.append orig.listElem(0)
      self.mergeAtAux(r, origValue, key.slice(k.len), value)
      return r.finish()

    self.dbDel orig.rawData
    if sharedNibbles > 0:
      # Split the extension node
      var bottom = initRlpList(2)
      bottom.append hexPrefixEncode(k.slice(sharedNibbles), isLeaf)
      bottom.append origValue

      var top = initRlpList(2)
      top.append hexPrefixEncode(k.slice(0, sharedNibbles), false)
      top.append dbSaveRlp(self.db, bottom.finish())

      return self.mergeAt(rlpFromBytes(top.finish()), key, value, true)
    else:
      # Create a branch node
      var branches = initRlpList(17)
      if k.len == 0:
        # The key is now exhausted. This must be a leaf node
        assert isLeaf
        for i in 0 ..< 16:
          branches.append ""
        branches.append origValue

      else:
        let n = k[0]
        for i in 0 ..< 16:
          if byte(i) == n:
            if isLeaf or k.len > 1:
              let childNode = encodeList(hexPrefixEncode(k.slice(1), isLeaf), origValue.rawData)
              branches.append dbSaveRlp(self.db, childNode)
          else:
            branches.append ""
        branches.append ""

      return self.mergeAt(rlpFromBytes(branches.finish()), key, value, true)

  else:
    if key.len == 0:
      return self.place(orig, key, value)

    if isInline:
      discard self.db.del(origHash)

    let n = key[0]
    var i = 0
    var r = initRlpList(17)

    var origCopy = orig
    for elem in items(origCopy):
      if i == int(n):
        self.mergeAtAux(r, elem, key.slice(1), value)
      else:
        r.append(elem)
      inc i

    return r.finish()

proc put*(self: var Trie; key, value: BytesRange) =
  mixin get
  let rootHash = self.rootHash.hash

  var rootBytes = self.db.get(rootHash).toRange
  assert rootBytes.len > 0

  let newRootBytes = self.mergeAt(rlpFromBytes(rootBytes), rootHash,
                                  initNibbleRange(key), value)

  if rootBytes.len < 32:
    discard self.db.del(rootHash)

  assert newRootBytes.len >= 32
  self.rootHash = self.db.dbPut(newRootBytes)

