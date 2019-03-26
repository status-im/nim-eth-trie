# nim-trie

# MOVED TO https://github.com/status-im/nim-eth

Nim Implementation of the Ethereum Trie structure
---

[![Build Status (Travis)](https://img.shields.io/travis/status-im/nim-eth-trie/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/status-im/nim-eth-trie)
[![Windows build status (Appveyor)](https://img.shields.io/appveyor/ci/nimbus/nim-eth-trie/master.svg?label=Windows "Windows build status (Appveyor)")](https://ci.appveyor.com/project/nimbus/nim-eth-trie)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

## Hexary Trie

## Binary Trie

Binary-trie is a dictionary-like data structure to store key-value pair.
Much like it's sibling Hexary-trie, the key-value pair will be stored into key-value flat-db.
The primary difference with Hexary-trie is, each node of Binary-trie only consist of one or two child,
while Hexary-trie node can contains up to 16 or 17 child-nodes.

Unlike Hexary-trie, Binary-trie store it's data into flat-db without using rlp encoding.
Binary-trie store its value using simple **Node-Types** encoding.
The encoded-node will be hashed by keccak_256 and the hash value will be the key to flat-db.
Each entry in the flat-db will looks like:

|         key          |                    value                   |
|----------------------|--------------------------------------------|
| 32-bytes-keccak-hash | encoded-node(KV or BRANCH or LEAF encoded) |

### Node-Types
* KV = [0, encoded-key-path, 32 bytes hash of child]
* BRANCH = [1, 32 bytes hash of left child, 32 bytes hash of right child]
* LEAF = [2, value]

The KV node can have BRANCH node or LEAF node as it's child, but cannot a KV node.
The internal algorithm will merge a KV(parent)->KV(child) into one KV node.
Every KV node contains encoded keypath to reduce the number of blank nodes.

The BRANCH node can have KV, BRANCH, or LEAF node as it's children.

The LEAF node is the terminal node, it contains the value of a key.

### encoded-key-path

While Hexary-trie encode the path using Hex-Prefix encoding, Binary-trie
encode the path using binary encoding, the scheme looks like this table below.

```text
            |--------- odd --------|
       00mm yyyy xxxx xxxx xxxx xxxx
            |------ even -----|
  1000 00mm yyyy xxxx xxxx xxxx
```

| symbol | explanation |
|--------|--------------------------|
| xxxx   | nibble of binary keypath in bits, 0 = left, 1 = right|
| yyyy   | nibble contains 0-3 bits padding + binary keypath |
| mm     | number of binary keypath bits modulo 4 (0-3) |
| 00     | zero zero prefix |
| 1000   | even numbered nibbles prefix |

if there is no padding, then yyyy bit sequence is absent, mm also zero.
yyyy = mm bits + padding bits must be 4 bits length.

### The API

The primary API for Binary-trie is `set` and `get`.
* set(key, value)  ---  _store a value associated with a key_
* get(key): value  --- _get a value using a key_

Both `key` and `value` are of `BytesRange` type. And they cannot have zero length.
You can also use convenience API `get` and `set` which accepts
`Bytes` or `string` (a `string` is conceptually wrong in this context
and may costlier than a `BytesRange`, but it is good for testing purpose).

Getting a non-existent key will return zero length BytesRange.

Binary-trie also provide dictionary syntax API for `set` and `get`.
* trie[key] = value -- same as `set`
* value = trie[key] -- same as `get`
* contains(key) a.k.a. `in` operator

Additional APIs are:
 * exists(key) -- returns `bool`, to check key-value existence -- same as contains
 * delete(key) -- remove a key-value from the trie
 * deleteSubtrie(key) -- remove a key-value from the trie plus all of it's subtrie
   that starts with the same key prefix
 * rootNode() -- get root node
 * rootNode(node) -- replace the root node
 * getRootHash(): `KeccakHash` with `BytesRange` type
 * getDB(): `DB` -- get flat-db pointer

Constructor API:
 * initBinaryTrie(DB, rootHash[optional]) -- rootHash has `BytesRange` or KeccakHash type
 * init(BinaryTrie, DB, rootHash[optional])

Normally you would not set the rootHash when constructing an empty Binary-trie.
Setting the rootHash occured in a scenario where you have a populated DB
with existing trie structure and you know the rootHash,
and then you want to continue/resume the trie operations.

## Examples

```Nim
import
  eth_trie/[db, binary, utils]

var db = newMemoryDB()
var trie = initBinaryTrie(db)
trie.set("key1", "value1")
trie.set("key2", "value2")
assert trie.get("key1") == "value1".toRange
assert trie.get("key2") == "value2".toRange

# delete all subtrie with key prefixes "key"
trie.deleteSubtrie("key")
assert trie.get("key1") == zeroBytesRange
assert trie.get("key2") == zeroBytesRange

trie["moon"] = "sun"
assert "moon" in trie
assert trie["moon"] == "sun".toRange
```

Remember, `set` and `get` are trie operations. A single `set` operation may invoke
more than one store/lookup operation into the underlying DB. The same is also happened to `get` operation,
it could do more than one flat-db lookup before it return the requested value.

## The truth behind a lie

What kind of lie? actually, `delete` and `deleteSubtrie` doesn't remove the
'deleted' node from the underlying DB. It only make the node inaccessible
from the user of the trie. The same also happened if you update the value of a key,
the old value node is not removed from the underlying DB.
A more subtle lie also happened when you add new entrie into the trie using `set` operation.
The previous hash of affected branch become obsolete and replaced by new hash,
the old hash become inaccessible to the user.
You may think that is a waste of storage space.
Luckily, we also provide some utilities to deal with this situation, the branch utils.

## The branch utils

The branch utils consist of these API:
 * checkIfBranchExist(DB; rootHash; keyPrefix): bool
 * getBranch(DB; rootHash; key): branch
 * isValidBranch(branch, rootHash, key, value): bool
 * getWitness(DB; nodeHash; key): branch
 * getTrieNodes(DB; nodeHash): branch

`keyPrefix`, `key`, and `value` are bytes container with length greater than zero.
They can be BytesRange, Bytes, and string(again, for convenience and testing purpose).

`rootHash` and `nodeHash` also bytes container,
but they have constraint: must be 32 bytes in length, and it must be a keccak_256 hash value.

`branch` is a list of nodes, or in this case a seq[BytesRange].
A list? yes, the structure is stored along with the encoded node.
Therefore a list is enough to reconstruct the entire trie/branch.

```Nim
import
  eth_trie/[db, binary, utils]

var db = newMemoryDB()
var trie = initBinaryTrie(db)
trie.set("key1", "value1")
trie.set("key2", "value2")

assert checkIfBranchExist(db, trie.getRootHash(), "key") == true
assert checkIfBranchExist(db, trie.getRootHash(), "key1") == true
assert checkIfBranchExist(db, trie.getRootHash(), "ken") == false
assert checkIfBranchExist(db, trie.getRootHash(), "key123") == false
```

The tree will looks like:
```text
    root --->  A(kvnode, *common key prefix*)
                         |
                         |
                         |
                    B(branchnode)
                     /         \
                    /           \
                   /             \
C1(kvnode, *remain kepath*) C2(kvnode, *remain kepath*)
            |                           |
            |                           |
            |                           |
  D1(leafnode, b'value1')       D2(leafnode, b'value2')
```

```Nim
var branchA = getBranch(db, trie.getRootHash(), "key1")
# ==> [A, B, C1, D1]

var branchB = getBranch(db, trie.getRootHash(), "key2")
# ==> [A, B, C2, D2]

assert isValidBranch(branchA, trie.getRootHash(), "key1", "value1") == true
# wrong key, return zero bytes
assert isValidBranch(branchA, trie.getRootHash(), "key5", "") == true

assert isValidBranch(branchB, trie.getRootHash(), "key1", "value1") # InvalidNode

var x = getBranch(db, trie.getRootHash(), "key")
# ==> [A]

x = getBranch(db, trie.getRootHash(), "key123") # InvalidKeyError
x = getBranch(db, trie.getRootHash(), "key5") # there is still branch for non-exist key
# ==> [A]

var branch = getWitness(db, trie.getRootHash(), "key1")
# equivalent to `getBranch(db, trie.getRootHash(), "key1")`
# ==> [A, B, C1, D1]

branch = getWitness(db, trie.getRootHash(), "key")
# this will include additional nodes of "key2"
# ==> [A, B, C1, D1, C2, D2]

var wholeTrie = getWitness(db, trie.getRootHash(), "")
# this will return the whole trie
# ==> [A, B, C1, D1, C2, D2]

var node = branch[1] # B
let nodeHash = keccak256.digest(node.baseAddr, uint(node.len))
var nodes = getTrieNodes(db, nodeHash)
assert nodes.len == wholeTrie.len - 1
# ==> [B, C1, D1, C2, D2]
```

## Remember the lie?

Because trie `delete`, `deleteSubtrie` and `set` operation create inaccessible nodes in the underlying DB,
we need to remove them if necessary. We already see that `wholeTrie = getWitness(db, trie.getRootHash(), "")`
will return the whole trie, a list of accessible nodes.
Then we can write the clean tree into a new DB instance to replace the old one.


## Sparse Merkle Trie

Sparse Merkle Trie(SMT) is a variant of Binary Trie which uses binary encoding to
represent path during trie travelsal. When Binary Trie uses three types of node,
SMT only use one type of node without any additional special encoding to store it's key-path.

Actually, it doesn't even store it's key-path anywhere like Binary Trie,
the key-path is stored implicitly in the trie structure during key-value insertion.

Because the key-path is not encoded in any special ways, the bits can be extracted directly from
the key without any conversion.

However, the key restricted to a fixed length because the algorithm demand a fixed height trie
to works properly. In this case, the trie height is limited to 160 level,
or the key is of fixed length 20 bytes (8 bits x 20 = 160).

To be able to use variable length key, the algorithm can be adapted slightly using hashed key before
constructing the binary key-path. For example, if using keccak256 as the hashing function,
then the height of the tree will be 256, but the key itself can be any length.

### The API

The primary API for Binary-trie is `set` and `get`.
* set(key, value, rootHash[optional])  ---  _store a value associated with a key_
* get(key, rootHash[optional]): value  --- _get a value using a key_

Both `key` and `value` are of `BytesRange` type. And they cannot have zero length.
You can also use convenience API `get` and `set` which accepts
`Bytes` or `string` (a `string` is conceptually wrong in this context
and may costlier than a `BytesRange`, but it is good for testing purpose).

rootHash is an optional parameter. When used, `get` will get a key from specific root,
and `set` will also set a key at specific root.

Getting a non-existent key will return zero length BytesRange or a zeroBytesRange.

Sparse Merkle Trie also provide dictionary syntax API for `set` and `get`.
 * trie[key] = value -- same as `set`
 * value = trie[key] -- same as `get`
 * contains(key) a.k.a. `in` operator

Additional APIs are:
 * exists(key) -- returns `bool`, to check key-value existence -- same as contains
 * delete(key) -- remove a key-value from the trie
 * getRootHash(): `KeccakHash` with `BytesRange` type
 * getDB(): `DB` -- get flat-db pointer
 * prove(key, rootHash[optional]): proof -- useful for merkling

Constructor API:
 * initSparseBinaryTrie(DB, rootHash[optional])
 * init(SparseBinaryTrie, DB, rootHash[optional])

Normally you would not set the rootHash when constructing an empty Sparse Merkle Trie.
Setting the rootHash occured in a scenario where you have a populated DB
with existing trie structure and you know the rootHash,
and then you want to continue/resume the trie operations.

## Examples

```Nim
import
  eth_trie/[db, sparse_binary, utils]

var
  db = newMemoryDB()
  trie = initSparseMerkleTrie(db)

let
  key1 = "01234567890123456789"
  key2 = "abcdefghijklmnopqrst"

trie.set(key1, "value1")
trie.set(key2, "value2")
assert trie.get(key1) == "value1".toRange
assert trie.get(key2) == "value2".toRange

trie.delete(key1)
assert trie.get(key1) == zeroBytesRange

trie.delete(key2)
assert trie[key2] == zeroBytesRange
```

Remember, `set` and `get` are trie operations. A single `set` operation may invoke
more than one store/lookup operation into the underlying DB. The same is also happened to `get` operation,
it could do more than one flat-db lookup before it return the requested value.
While Binary Trie perform a variable numbers of lookup and store operations, Sparse Merkle Trie
will do constant numbers of lookup and store operations each `get` and `set` operation.

## Merkle Proofing

Using ``prove`` dan ``verifyProof`` API, we can do some merkling with SMT.

```Nim
  let
    value1 = "hello world"
    badValue = "bad value"

  trie[key1] = value1
  var proof = trie.prove(key1)

  assert verifyProof(proof, trie.getRootHash(), key1, value1) == true
  assert verifyProof(proof, trie.getRootHash(), key1, badValue) == false
  assert verifyProof(proof, trie.getRootHash(), key2, value1) == false
```

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. This file may not be copied, modified, or distributed except according to those terms.
