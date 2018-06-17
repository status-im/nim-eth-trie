# nim-trie
Nim Implementation of the Ethereum Trie structure
---

[![Build Status][badge-nimtrie-travisci]][nimtrie-travisci]
[![Build status][badge-nimtrie-appveyor]][nimtrie-appveyor]

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
mm bits + padding bits must be 4 bits length.

### The API

The primary API for Binary-trie is `set` and `get`.
* set(key, value)  ---  _store a value associated with a key_
* get(key): value  --- _get a value using a key_

Both `key` and `value` are of `BytesRange` type. And they cannot have zero length.
You can also use convenience API `get` and `set` which accepts
`Bytes` or `string` (a `string` is conceptually wrong in this context
and may costlier than a `BytesRange`, but it is good for testing purpose).

Binary-trie also provide dictionary syntax for `set` and `get`.
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
 * getDB(): `ref DB` -- get flat-db pointer

Constructor API:
  * initBinaryTrie(ref DB, rootHash[optional]) -- rootHash has `BytesRange` type
  * init(BinaryTrie[DB], ref DB, rootHash[optional])

Normally you would not set the rootHash when constructing an empty Binary-trie.
Setting the rootHash occured in a scenario where you have a populated DB
with existing trie structure and you know the rootHash,
and then you want to continue/resume the trie operations.

## Examples

```Nim
import
  ethereum_trie/[memdb, binary, utils]

var db = newMemDB()
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
more than one store operation into the underlying DB. The same is also happened to `get` operation,
it could do more than one flat-db lookup before it return the requested value.

## The truth behind a lie

What kind of lie? actually, `delete` and `deleteSubtrie` doesn't remove the
'deleted' node from the underlying DB. It only make the node inaccessible
from the user of the trie. The same also happened if you update the value of a key,
the old value node is not removed from the underlying DB.
You may think that is a waste of storage space.
Luckily, we also provide some utilities to deal with this situation, the branch utils.

## The branch utils


[nimtrie-travisci]: https://travis-ci.org/status-im/nim-trie
[nimtrie-appveyor]: https://ci.appveyor.com/project/jarradh/nim-trie
[badge-nimtrie-travisci]: https://travis-ci.org/status-im/nim-trie.svg?branch=master
[badge-nimtrie-appveyor]: https://ci.appveyor.com/api/projects/status/github/jarradh/nim-trie?svg=true
