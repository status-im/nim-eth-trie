import
  tables,
  nimcrypto/[keccak, hash, utils], ranges/ptr_arith, rlp,
  defs, nibbles, utils as trieUtils, db

type
  TrieNodeKey = object
    hash: KeccakHash
    usedBytes: uint8

  DB = TrieDatabaseRef

  HexaryTrie* = object
    db*: DB
    root: TrieNodeKey

  SecureHexaryTrie* = distinct HexaryTrie

  TrieNode = Rlp

  TrieError* = object of Exception
  CorruptedTrieError* = object of TrieError
  PersistenceFailure* = object of TrieError

template len(key: TrieNodeKey): int =
  key.usedBytes.int

proc keccak*(r: BytesRange): KeccakHash =
  keccak256.digest r.toOpenArray

template asDbKey(k: TrieNodeKey): untyped =
  assert k.usedBytes == 32
  k.hash.data

proc expectHash(r: Rlp): BytesRange =
  result = r.toBytes
  if result.len != 32:
    raise newException(RlpTypeMismatch,
      "RLP expected to be a Keccak hash value, but has an incorrect length")

proc dbPut(db: DB, data: BytesRange): TrieNodeKey

template get(db: DB, key: Rlp): BytesRange =
  db.get(key.expectHash.toOpenArray).toRange

converter toTrieNodeKey(hash: KeccakHash): TrieNodeKey =
  result.hash = hash
  result.usedBytes = 32

proc initHexaryTrie*(db: DB, rootHash: KeccakHash): HexaryTrie =
  result.db = db
  result.root = rootHash

template initSecureHexaryTrie*(db: DB, rootHash: KeccakHash): SecureHexaryTrie =
  SecureHexaryTrie initHexaryTrie(db, rootHash)

let
  # XXX: turning this into a constant leads to a compilation failure
  emptyRlp = rlp.encode ""

proc initHexaryTrie*(db: DB): HexaryTrie =
  result.db = db
  result.root = result.db.dbPut(emptyRlp.toRange)

proc rootHash*(t: HexaryTrie): KeccakHash =
  t.root.hash

proc rootHashHex*(t: HexaryTrie): string =
  $t.root.hash

proc getLocalBytes(x: TrieNodeKey): BytesRange =
  ## This proc should be used on nodes using the optimization
  ## of short values within the key.
  assert x.usedBytes < 32

  when defined(rangesEnableUnsafeAPI):
    result = unsafeRangeConstruction(x.data, x.usedBytes)
  else:
    var dataCopy = newSeq[byte](x.usedBytes)
    copyMem(dataCopy.baseAddr, x.hash.data.baseAddr, x.usedBytes)
    return dataCopy.toRange

template keyToLocalBytes(db: DB, k: TrieNodeKey): BytesRange =
  if k.len < 32: k.getLocalBytes
  else: db.get(k.asDbKey).toRange

template extensionNodeKey(r: Rlp): auto =
  hexPrefixDecode r.listElem(0).toBytes

proc getAux(db: DB, nodeRlp: Rlp, path: NibblesRange): BytesRange

proc getAuxByHash(db: DB, node: TrieNodeKey, path: NibblesRange): BytesRange =
  var nodeRlp = rlpFromBytes keyToLocalBytes(db, node)
  return getAux(db, nodeRlp, path)

template getLookup(elem: untyped): untyped =
  if elem.isList: elem
  else: rlpFromBytes(get(db, toOpenArray(elem.expectHash)).toRange)

proc getAux(db: DB, nodeRlp: Rlp, path: NibblesRange): BytesRange =
  if not nodeRlp.hasData or nodeRlp.isEmpty:
    return zeroBytesRange

  case nodeRlp.listLen
  of 2:
    let (isLeaf, k) = nodeRlp.extensionNodeKey
    let sharedNibbles = sharedPrefixLen(path, k)

    if sharedNibbles == k.len:
      let value = nodeRlp.listElem(1)
      if sharedNibbles == path.len and isLeaf:
        return value.toBytes
      elif not isLeaf:
        let nextLookup = value.getLookup
        return getAux(db, nextLookup, path.slice(sharedNibbles))

    return zeroBytesRange
  of 17:
    if path.len == 0:
      return nodeRlp.listElem(16).toBytes
    var branch = nodeRlp.listElem(path[0].int)
    if branch.isEmpty:
      return zeroBytesRange
    else:
      let nextLookup = branch.getLookup
      return getAux(db, nextLookup, path.slice(1))
  else:
    raise newException(CorruptedTrieError,
                       "HexaryTrie node with an unexpected numbef or children")

proc get*(self: HexaryTrie; key: BytesRange): BytesRange =
  return getAuxByHash(self.db, self.root, initNibbleRange(key))

proc getLeavesAux(db: DB, nodeRlp: Rlp, leaves: var seq[BytesRange]) =
  if not nodeRlp.hasData or nodeRlp.isEmpty:
    return

  case nodeRlp.listLen
  of 2:
    let
      (isLeaf, k) = nodeRlp.extensionNodeKey
      value = nodeRlp.listElem(1)

    if isLeaf:
      leaves.add value.toBytes
    else:
      let nextLookup = value.getLookup
      db.getLeavesAux(nextLookup, leaves)
  of 17:
    var lastElem = nodeRlp.listElem(16)
    if not lastElem.isEmpty:
      leaves.add lastElem.toBytes
    for i in 0 ..< 16:
      var branch = nodeRlp.listElem(i)
      if not branch.isEmpty:
        let nextLookup = branch.getLookup
        db.getLeavesAux(nextLookup, leaves)
  else:
    raise newException(CorruptedTrieError,
                       "HexaryTrie node with an unexpected numbef or children")

proc getLeaves*(self: HexaryTrie): seq[BytesRange] =
  result = @[]
  var nodeRlp = rlpFromBytes keyToLocalBytes(self.db, self.root)
  self.db.getLeavesAux(nodeRlp, result)

proc dbDel(t: var HexaryTrie, data: BytesRange) =
  if data.len >= 32: t.db.del(data.keccak.data)

proc dbPut(db: DB, data: BytesRange): TrieNodeKey =
  result.hash = data.keccak
  result.usedBytes = 32
  put(db, result.asDbKey, data.toOpenArray)

proc appendAndSave(rlpWriter: var RlpWriter, data: BytesRange, db: DB) =
  if data.len >= 32:
    var nodeKey = dbPut(db, data)
    rlpWriter.append(nodeKey.hash)
  else:
    rlpWriter.appendRawBytes(data)

proc isTrieBranch(rlp: Rlp): bool =
  rlp.isList and (var len = rlp.listLen; len == 2 or len == 17)

proc replaceValue(data: Rlp, key: NibblesRange, value: BytesRange): Bytes =
  if data.isEmpty:
    let prefix = hexPrefixEncode(key, true)
    return encodeList(prefix, value)

  assert data.isTrieBranch
  if data.listLen == 2:
    return encodeList(data.listElem(0), value)

  var r = initRlpList(17)

  # XXX: This can be optmized to a direct bitwise copy of the source RLP
  var iter = data
  iter.enterList()
  for i in 0 ..< 16:
    r.append iter
    iter.skipElem

  r.append value
  return r.finish()

proc isTwoItemNode(self: HexaryTrie; r: Rlp): bool =
  if r.isBlob:
    let resolved = self.db.get(r)
    let rlp = rlpFromBytes(resolved)
    return rlp.isList and rlp.listLen == 2
  else:
    return r.isList and r.listLen == 2

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

proc deleteAt(self: var HexaryTrie; origRlp: Rlp, key: NibblesRange): BytesRange

proc deleteAux(self: var HexaryTrie; rlpWriter: var RlpWriter;
               origRlp: Rlp; path: NibblesRange): bool =
  if origRlp.isEmpty:
    return false

  var toDelete = if origRlp.isList: origRlp
                 else: rlpFromBytes self.db.get(origRlp)

  let b = self.deleteAt(toDelete, path)

  if b.len == 0:
    return false

  rlpWriter.appendAndSave(b, self.db)
  return true

proc graft(self: var HexaryTrie; r: Rlp): Bytes =
  assert r.isList and r.listLen == 2
  var (origIsLeaf, origPath) = r.extensionNodeKey
  var value = r.listElem(1)

  var n: Rlp
  if not value.isList:
    let nodeKey = value.expectHash
    var resolvedData = self.db.get(nodeKey.toOpenArray).toRange
    self.db.del(nodeKey.toOpenArray)
    value = rlpFromBytes resolvedData

  assert value.listLen == 2
  let (valueIsLeaf, valueKey) = value.extensionNodeKey

  var rlpWriter = initRlpList(2)
  rlpWriter.append hexPrefixEncode(origPath, valueKey, valueIsLeaf)
  rlpWriter.append value.listElem(1)
  return rlpWriter.finish

proc mergeAndGraft(self: var HexaryTrie;
                   soleChild: Rlp, childPos: byte): Bytes =
  var output = initRlpList(2)
  if childPos == 16:
    output.append hexPrefixEncode(zeroNibblesRange, true)
  else:
    assert(not soleChild.isEmpty)
    output.append int(hexPrefixEncodeByte(childPos))
  output.append(soleChild)
  result = output.finish()

  if self.isTwoItemNode(soleChild):
    result = self.graft(rlpFromBytes(result.toRange))

proc deleteAt(self: var HexaryTrie;
              origRlp: Rlp, key: NibblesRange): BytesRange =
  if origRlp.isEmpty:
    return zeroBytesRange

  assert origRlp.isTrieBranch
  let origBytes = origRlp.rawData
  if origRlp.listLen == 2:
    let (isLeaf, k) = origRlp.extensionNodeKey
    if k == key and isLeaf:
      self.dbDel origBytes
      return emptyRlp.toRange

    if key.startsWith(k):
      var
        rlpWriter = initRlpList(2)
        path = origRlp.listElem(0)
        value = origRlp.listElem(1)
      rlpWriter.append(path)
      if not self.deleteAux(rlpWriter, value, key.slice(k.len)):
        return zeroBytesRange
      self.dbDel origBytes
      var finalBytes = rlpWriter.finish.toRange
      var rlp = rlpFromBytes(finalBytes)
      if self.isTwoItemNode(rlp.listElem(1)):
        return self.graft(rlp).toRange
      return finalBytes
    else:
      return zeroBytesRange
  else:
    if key.len == 0 and origRlp.listElem(16).isEmpty:
      self.dbDel origBytes
      var foundChildPos: byte
      let singleChild = origRlp.findSingleChild(foundChildPos)
      if singleChild.hasData and foundChildPos != 16:
        result = self.mergeAndGraft(singleChild, foundChildPos).toRange
      else:
        var rlpRes = initRlpList(17)
        var iter = origRlp
        iter.enterList
        for i in 0 ..< 16:
          rlpRes.append iter
          iter.skipElem
        rlpRes.append ""
        return rlpRes.finish.toRange
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
      result = rlpWriter.finish.toRange
      var resultRlp = rlpFromBytes(result)
      var foundChildPos: byte
      let singleChild = resultRlp.findSingleChild(foundChildPos)
      if singleChild.hasData:
        result = self.mergeAndGraft(singleChild, foundChildPos).toRange

proc del*(self: var HexaryTrie; key: BytesRange) =
  var
    rootBytes = keyToLocalBytes(self.db, self.root)
    rootRlp = rlpFromBytes rootBytes

  var newRootBytes = self.deleteAt(rootRlp, initNibbleRange(key))
  if newRootBytes.len > 0:
    if rootBytes.len < 32:
      self.db.del(self.root.asDbKey)
    self.root = self.db.dbPut(newRootBytes)

proc mergeAt(self: var HexaryTrie, orig: Rlp, origHash: KeccakHash,
             key: NibblesRange, value: BytesRange,
             isInline = false): BytesRange

proc mergeAt(self: var HexaryTrie, rlp: Rlp,
             key: NibblesRange, value: BytesRange,
             isInline = false): BytesRange =
  self.mergeAt(rlp, rlp.rawData.keccak, key, value, isInline)

proc mergeAtAux(self: var HexaryTrie, output: var RlpWriter, orig: Rlp,
                key: NibblesRange, value: BytesRange) =
  var resolved = orig
  var isRemovable = false
  if not (orig.isList or orig.isEmpty):
    resolved = rlpFromBytes self.db.get(orig)
    isRemovable = true

  let b = self.mergeAt(resolved, key, value, not isRemovable)
  output.appendAndSave(b, self.db)

proc mergeAt(self: var HexaryTrie, orig: Rlp, origHash: KeccakHash,
             key: NibblesRange, value: BytesRange,
             isInline = false): BytesRange =
  template origWithNewValue: auto =
    self.db.del(origHash.data)
    replaceValue(orig, key, value).toRange

  if orig.isEmpty:
    return origWithNewValue()

  assert orig.isTrieBranch
  if orig.listLen == 2:
    let (isLeaf, k) = orig.extensionNodeKey
    var origValue = orig.listElem(1)

    if k == key and isLeaf:
      return origWithNewValue()

    let sharedNibbles = sharedPrefixLen(key, k)

    if sharedNibbles == k.len and not isLeaf:
      var r = initRlpList(2)
      r.append orig.listElem(0)
      self.mergeAtAux(r, origValue, key.slice(k.len), value)
      return r.finish.toRange

    if orig.rawData.len >= 32:
      self.db.del(origHash.data)

    if sharedNibbles > 0:
      # Split the extension node
      var bottom = initRlpList(2)
      bottom.append hexPrefixEncode(k.slice(sharedNibbles), isLeaf)
      bottom.append origValue

      var top = initRlpList(2)
      top.append hexPrefixEncode(k.slice(0, sharedNibbles), false)
      top.appendAndSave(bottom.finish.toRange, self.db)

      return self.mergeAt(rlpFromBytes(top.finish.toRange), key, value, true)
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
              let childNode = encodeList(hexPrefixEncode(k.slice(1), isLeaf),
                                         origValue).toRange
              branches.appendAndSave(childNode, self.db)
            else:
              branches.append origValue
          else:
            branches.append ""
        branches.append ""

      return self.mergeAt(rlpFromBytes(branches.finish.toRange), key, value, true)
  else:
    if key.len == 0:
      return origWithNewValue()

    if isInline:
      self.db.del(origHash.data)

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

    return r.finish.toRange

proc put*(self: var HexaryTrie; key, value: BytesRange) =
  let root = self.root.hash

  var rootBytes = self.db.get(root.data).toRange
  assert rootBytes.len > 0

  let newRootBytes = self.mergeAt(rlpFromBytes(rootBytes), root,
                                  initNibbleRange(key), value)
  if rootBytes.len < 32:
    self.db.del(root.data)

  self.root = self.db.dbPut(newRootBytes)

proc put*(self: var SecureHexaryTrie; key, value: BytesRange) =
  let keyHash = @(key.keccak.data)
  put(HexaryTrie(self), keyHash.toRange, value)

proc get*(self: SecureHexaryTrie; key: BytesRange): BytesRange =
  let keyHash = @(key.keccak.data)
  return get(HexaryTrie(self), keyHash.toRange)

proc del*(self: var SecureHexaryTrie; key: BytesRange) =
  let keyHash = @(key.keccak.data)
  del(HexaryTrie(self), keyHash.toRange)

proc rootHash*(self: SecureHexaryTrie): KeccakHash {.borrow.}
proc rootHashHex*(self: SecureHexaryTrie): string {.borrow.}

template contains*(self: HexaryTrie | SecureHexaryTrie;
                   key: BytesRange): bool =
  self.get(key).len > 0

