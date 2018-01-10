
import
  pytest, hypothesis, trie.binary, trie.constants, trie.exceptions

var st = hypothesis.strategies
proc testBinTrieDeleteSubtrie*(kv1: (); kv2: (); keyToBeDeleted: cstring;
                              willDelete: bool; willRasieError: bool): void =
  var trie = BinaryTrie()
  trie.set(kv1[0], kv1[1])
  trie.set(kv2[0], kv2[1])
  nil
  nil
  if willDelete:
    trie.deleteSubtrie(keyToBeDeleted)
    nil
    nil
    nil
  elif willRasieError:
    with
      trie.deleteSubtrie(keyToBeDeleted)
  else:
    rootHashBeforeDelete = trie.rootHash
    trie.deleteSubtrie(keyToBeDeleted)
  
