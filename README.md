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
while Hexary-trie node can contains up to 16 child-node.

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

if there is no padding, then yyyy bit sequence is absent, mm also zero. mm bits + padding bits must be 4 bits length.

[nimtrie-travisci]: https://travis-ci.org/status-im/nim-eth-trie
[nimtrie-appveyor]: https://ci.appveyor.com/project/jarradh/nim-trie
[badge-nimtrie-travisci]: https://travis-ci.org/status-im/nim-eth-trie.svg?branch=master
[badge-nimtrie-appveyor]: https://ci.appveyor.com/api/projects/status/github/jarradh/nim-trie?svg=true
