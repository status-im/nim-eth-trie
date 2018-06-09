# nim-trie
Nim Implementation of the Ethereum Trie structure
---

[![Build Status][badge-nimtrie-travisci]][nimtrie-travisci]
[![Build status][badge-nimtrie-appveyor]][nimtrie-appveyor]

### Node Types
* KV
  0, encoded key path, 32 byte hash
* BRANCH
  1, 32 byte hash, 32 byte hash
* LEAF
  2, Nothing, value

### encoded key path
```text
            |--------- odd --------|
       00mm yyyy xxxx xxxx xxxx xxxx
            |------ even -----|
  1000 00mm yyyy xxxx xxxx xxxx
```

xxxx nibble of binary keypath
yyyy nibble contains 0-3 bits padding + binary keypath
mm   number of padding bits
00   zero zero prefix
1000 even numbered nibbles prefix


[nimtrie-travisci]: https://travis-ci.org/status-im/nim-trie
[nimtrie-appveyor]: https://ci.appveyor.com/project/jarradh/nim-trie
[badge-nimtrie-travisci]: https://travis-ci.org/status-im/nim-trie.svg?branch=master
[badge-nimtrie-appveyor]: https://ci.appveyor.com/api/projects/status/github/jarradh/nim-trie?svg=true
