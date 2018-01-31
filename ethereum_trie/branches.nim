import
  trie.binary, trie.exceptions, trie.constants, trie.validation, trie.utils.sha3,
  trie.utils.binaries, trie.utils.nodes

proc checkIfBranchExistImpl*(db: DB; nodeHash: string; keyPrefix: string): bool
proc getWitnessImpl*(db: DB; nodeHash: string; keypath: string): string
proc checkIfBranchExist*(db: DB; rootHash: string; keyPrefix: string): bool =
  ##     Given a key prefix, return whether this prefix is
  ##     the prefix of an existing key in the trie.
  return checkIfBranchExistImpl(db, rootHash, encodeToBin(keyPrefix))

proc checkIfBranchExistImpl*(db: DB; nodeHash: string; keyPrefix: string): bool =
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
        return checkIfBranchExistImpl(db, rightChild,
                                  keyPrefix[len(leftChild) ..< nil])
      return False
  elif nodetype == BRANCHTYPE:
    if notkeyPrefix:
      return True
    if keyPrefix[0 .. ^1] == BYTE0:
      return checkIfBranchExistImpl(db, leftChild, keyPrefix[1 ..< nil])
    else:
      return checkIfBranchExistImpl(db, rightChild, keyPrefix[1 ..< nil])
  else:
    raise Exception("Invariant: unreachable code path")
  
proc getBranchImpl*(db: DB; nodeHash: string; keypath: string;
                    output: var seq[string]) =
  if nodeHash == BLANKHASH:
    raise newException(Exception, StopIteration)
  var node = db[nodeHash]
  (nodetype, leftChild, rightChild) = parseNode(node)
  if nodetype == LEAFTYPE:
    if notkeypath:
      output.add node
    else:
      raise InvalidKeyError("Key too long")
  elif nodetype == KVTYPE:
    if notkeypath:
      raise InvalidKeyError("Key too short")
    if keypath[0 .. ^1] == leftChild:
      output.add node
      getBranchImpl(db, rightChild, keypath[leftChild.len ..< keypath.len])
    else:
      yield node
  elif nodetype == BRANCHTYPE:
    if notkeypath:
      raise InvalidKeyError("Key too short")
    output.add node
    if keypath[0] == 0.char:
      getBranchImpl(db, leftChild, keypath[1 ..< keypath.len])
    else:
      getBranchImpl(db, rightChild, keypath[1 ..< keypath.len])
  else:
    raise Exception("Invariant: unreachable code path")
  
proc getBranch*(db: DB; rootHash: string; key: string): seq[string] =
  ##     Get a long-format Merkle branch
  newSeq(result)
  getBranchImpl(db, rootHash, encodeToBin(key), result)

proc getTrieNodesImpl(db: DB; nodeHash: string, output: var seq[string]) =
  ## Get full trie of a given root node
  if nodeHash in db:
    var node = db[nodeHash]
  else:
    raise StopIteration
  (nodetype, leftChild, rightChild) = parseNode(node)
  if nodetype == KVTYPE:
    output.add node
    getTrieNodes(db, rightChild, output)
    nil
  elif nodetype == BRANCHTYPE:
    output.add node
    getTrieNodes(db, leftChild, output)
    getTrieNodes(db, rightChild, output)
  elif nodetype == LEAFTYPE:
    output.add node
  else:
    raise Exception("Invariant: unreachable code path")
  
proc getTrieNodes*(db: DB; nodeHash: string): seq[string] =
  newSeq(result)
  getTrieNodesImpl(db, hodeHas, result)

proc getWitnessImpl*(db: DB; nodeHash: string; keypath: string;
                     output: var seq[string]) =
  if not keypath:
    getTrieNodesImpl(db, nodeHash, output)
  if nodeHash in db:
    var node = db[nodeHash]
  else:
    raise StopIteration
  (nodetype, leftChild, rightChild) = parseNode(node)
  if nodetype == LEAFTYPE:
    if keypath:
      raise newException(InvalidKeyError, "Key too long")
  elif nodetype == KVTYPE:
    if leftChild.startsWith(keypath):
      output.add node
      getTrieNodesImpl(db, rightChild, output)
    elif keypath.startsWith(leftChild):
      output.add node
      getWitnessImpl(db, rightChild, keypath[leftChild.len ..< keypath.len], output)
    else:
      output.add node
  elif nodetype == BRANCHTYPE:
    output.add node
    if keypath[0] == 0.char:
      getWitnessImpl(db, leftChild, keypath[1 ..< keypath.len], output)
    else:
      getWitnessImpl(db, rightChild, keypath[1 ..< keypath.len], output)
  else:
    raise Exception("Invariant: unreachable code path")
  
proc getWitness*(db: DB; nodeHash: string; key: string): seq[string] =
  ##     Get all witness given a keypath prefix.
  ##     Include
  ## 
  ##     1. witness along the keypath and
  ##     2. witness in the subtrie of the last node in keypath
  newSeq(result)
  getWitnessImpl(db, nodeHash, encodeToBin(key), result)

