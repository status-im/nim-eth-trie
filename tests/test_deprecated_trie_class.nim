
import
  py2nim_helpers, pytest, trie

proc testDeprecatedTrie*(): void =
  with pytest.warns(DeprecationWarning),
    var trie = Trie()
  trie[cstring"foo"] = cstring"bar"
  nil
  nil

