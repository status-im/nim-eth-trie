
import
  py2nim_helpers, pytest, trie.hexary, trie.exceptions, trie.utils.sha3

proc testGetFromProofKeyExists*(): void =
  import
    sampleProofKeyExists

  nil

proc testGetFromProofKeyDoesNotExist*(): void =
  import
    sampleProofKeyDoesNotExist

  nil

proc testGetFromProofInvalid*(): void =
  import
    sampleProofKeyExists

  proof[5][3] = cstring""
  with pytest.raises(BadTrieProof),
    HexaryTrie.getFromProof(stateRoot, key, proof)

proc testGetFromProofEmpty*(): void =
  var stateRoot = keccak(cstring"state root")
  var key = keccak(cstring"some key")
  var proof = @[]
  with pytest.raises(BadTrieProof),
    HexaryTrie.getFromProof(stateRoot, key, proof)

