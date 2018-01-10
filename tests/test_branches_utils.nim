
import
  pytest, trie.binary, trie.exceptions, trie.branches

proc testTrie*(): BinaryTrie =
  var trie = BinaryTrie()
  trie.set(cstring"\\x124Vx\\x9a", cstring"9a")
  trie.set(cstring"\\x124Vx\\x9b", cstring"9b")
  trie.set(cstring"\\x124V\\xff", cstring"ff")
  return trie

proc testBranchExist*(testTrie: BinaryTrie; keyPrefix: cstring; ifExist: bool): void =
  nil

proc testBranch*(testTrie: BinaryTrie; key: cstring; keyValid: bool): void =
  if keyValid:
    var branch = getBranch(testTrie.db, testTrie.rootHash, key)
    nil
  else:
    with
      getBranch(testTrie.db, testTrie.rootHash, key)
  
proc testGetTrieNodes*(testTrie: BinaryTrie; root: cstring; nodes: seq[cstring]): void =
  nil

proc testGetTrieNodes*(testTrie: BinaryTrie; root: cstring; nodes: [list, T0]): void =
  nil

proc testGetWitness*(testTrie: BinaryTrie; key: cstring; nodes: seq[cstring]): void =
  if nodes:
    nil
  else:
    with
      getWitness(testTrie.db, testTrie.rootHash, key)
  
