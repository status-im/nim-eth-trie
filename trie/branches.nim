
import
  trie.binary, trie.exceptions, trie.constants, trie.validation, trie.utils.sha3,
  trie.utils.binaries, trie.utils.nodes

proc _checkIfBranchExist*(db: Table[cstring, cstring]; nodeHash: cstring;
                         keyPrefix: cstring): bool
proc _getWitness*(db: Table[cstring, cstring]; nodeHash: cstring; keypath: cstring): cstring
proc checkIfBranchExist*(db: Table[cstring, cstring]; rootHash: cstring;
                        keyPrefix: cstring): bool =
  ##     Given a key prefix, return whether this prefix is
  ##     the prefix of an existing key in the trie.
  validateIsBytes(keyPrefix)
  return _checkIfBranchExist(db, rootHash, encodeToBin(keyPrefix))

proc _checkIfBranchExist*(db: Table[cstring, cstring]; nodeHash: cstring;
                         keyPrefix: cstring): bool =
  if nodeHash == BLANKHASH:
    return false
  (nodetype, leftChild, rightChild) = parseNode(db[nodeHash])
  if nodetype == LEAFTYPE:
    if keyPrefix:
      return false
    return true
  elif nodetype == KVTYPE:
    if notkeyPrefix:
      return True
    if len(keyPrefix) < len(leftChild):
      if keyPrefix == leftChild[0 .. ^1]:
        return True
      return False
    else:
      if keyPrefix[0 .. ^1] == leftChild:
        return _checkIfBranchExist(db, rightChild,
                                  keyPrefix[len(leftChild) ..< nil])
      return False
  elif nodetype == BRANCHTYPE:
    if notkeyPrefix:
      return True
    if keyPrefix[0 .. ^1] == BYTE0:
      return _checkIfBranchExist(db, leftChild, keyPrefix[1 ..< nil])
    else:
      return _checkIfBranchExist(db, rightChild, keyPrefix[1 ..< nil])
  else:
    raise Exception("Invariant: unreachable code path")
  
proc getBranch*(db: Table[cstring, cstring]; rootHash: cstring; key: cstring): () =
  ##     Get a long-format Merkle branch
  validateIsBytes(key)
  return tuple(_getBranch(db, rootHash, encodeToBin(key)))

iterator _getBranch*(db: Table[cstring, cstring]; nodeHash: cstring; keypath: cstring): cstring =
  if nodeHash == BLANKHASH:
    raise newException(Exception, StopIteration)
  var node = db[nodeHash]
  (nodetype, leftChild, rightChild) = parseNode(node)
  if nodetype == LEAFTYPE:
    if notkeypath:
      yield node
    else:
      raise InvalidKeyError("Key too long")
  elif nodetype == KVTYPE:
    if notkeypath:
      raise InvalidKeyError("Key too short")
    if keypath[0 .. ^1] == leftChild:
      yield node
    else:
      yield node
  elif nodetype == BRANCHTYPE:
    if notkeypath:
      raise InvalidKeyError("Key too short")
    if keypath[0 .. ^1] == BYTE0:
      yield node
    else:
      yield node
  else:
    raise Exception("Invariant: unreachable code path")
  
proc getTrieNodes*(db: Table[cstring, cstring]; nodeHash: cstring): () =
  ##     Get full trie of a given root node
  return tuple(_getTrieNodes(db, nodeHash))

iterator _getTrieNodes*(db: Table[cstring, cstring]; nodeHash: cstring): cstring =
  if nodeHash in db:
    var node = db[nodeHash]
  else:
    raise StopIteration
  (nodetype, leftChild, rightChild) = parseNode(node)
  if nodetype == KVTYPE:
    yield node
    nil
  elif nodetype == BRANCHTYPE:
    yield node
  elif nodetype == LEAFTYPE:
    yield node
  else:
    raise Exception("Invariant: unreachable code path")
  
proc getWitness*(db: Table[cstring, cstring]; nodeHash: cstring; key: cstring): () =
  ##     Get all witness given a keypath prefix.
  ##     Include
  ## 
  ##     1. witness along the keypath and
  ##     2. witness in the subtrie of the last node in keypath
  validateIsBytes(key)
  return tuple(_getWitness(db, nodeHash, encodeToBin(key)))

proc _getWitness*(db: Table[cstring, cstring]; nodeHash: cstring; keypath: cstring): cstring =
  if notkeypath:
    nil
  if nodeHash in db:
    var node = db[nodeHash]
  else:
    raise StopIteration
  (nodetype, leftChild, rightChild) = parseNode(node)
  if nodetype == LEAFTYPE:
    if keypath:
      raise newException(InvalidKeyError, "Key too long")
  elif nodetype == KVTYPE:
    if :
      yield node
    elif keypath[0 .. ^1] == leftChild:
      yield node
    else:
      yield node
  elif nodetype == BRANCHTYPE:
    if keypath[0 .. ^1] == BYTE0:
      yield node
    else:
      yield node
  else:
    raise Exception("Invariant: unreachable code path")
  
