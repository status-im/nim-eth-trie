
import
  pkg_resources, warnings, binary, hexary

type
  Trie* = object of HexaryTrie
method makeTrie*(): Trie =
  warnings.simplefilter("always", DeprecationWarning)
  warnings.warn(DeprecationWarning("The `trie.Trie` class has been renamed to `trie.HexaryTrie`. Please update your code as the `trie.Trie` class will be removed in a subsequent release"))
  warnings.resetwarnings()
  super().__init__(nil)

var __version__ = 2
