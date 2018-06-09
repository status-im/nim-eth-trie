# nim-trie
Nim Implementation of the Ethereum Trie structure
---

[![Build Status][badge-nimtrie-travisci]][nimtrie-travisci]
[![Build status][badge-nimtrie-appveyor]][nimtrie-appveyor]

### Node-Types
* KV = [0, encoded-key-path, 32 bytes hash]
* BRANCH = [1, 32 bytes hash, 32 bytes hash]
* LEAF = [2, value]

### encoded-key-path
```text
            |--------- odd --------|
       00mm yyyy xxxx xxxx xxxx xxxx
            |------ even -----|
  1000 00mm yyyy xxxx xxxx xxxx
```

| symbol | explanation |
|--------|--------------------------|
| xxxx   | nibble of binary keypath |
| yyyy   | nibble contains 0-3 bits padding + binary keypath |
| mm     | number of padding bits |
| 00     | zero zero prefix |
| 1000   | even numbered nibbles prefix |

unlike hexary-trie, binary store it's data into flat-db without using rlp encoding.
binary-trie store its value using simple Node-Types encoding.
the encoded-node will be hashed by keccak_256 and the hash value will be the key to flat-db.
so each entry in the flat-db will looks like

|         key          |                    value                   |
|----------------------|--------------------------------------------|
| 32-bytes-keccak-hash | encoded-node(KV or BRANCH or LEAF encoded) |

[nimtrie-travisci]: https://travis-ci.org/status-im/nim-trie
[nimtrie-appveyor]: https://ci.appveyor.com/project/jarradh/nim-trie
[badge-nimtrie-travisci]: https://travis-ci.org/status-im/nim-trie.svg?branch=master
[badge-nimtrie-appveyor]: https://ci.appveyor.com/api/projects/status/github/jarradh/nim-trie?svg=true
