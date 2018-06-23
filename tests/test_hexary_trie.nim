import
  strutils,
  ranges/typedranges, eth_trie/[hexary, types, memdb],
  test_utils

template put(t: HexaryTrie|SecureHexaryTrie, key, val: string) =
  t.put(key.toBytesRange, val.toBytesRange)

template del(t: HexaryTrie|SecureHexaryTrie, key) =
  t.del(key.toBytesRange)

template get(t: HexaryTrie|SecureHexaryTrie, key): auto =
  t.get(key.toBytesRange)

when false:
  block:
    var
      db = trieDB newMemDB()
      t = initHexaryTrie(db)

    t.put("A", "a");
    t.put("B", "b")
    t.put("9", "9")

    echo t.get("A").toOpenArray
    echo t.get("9").toOpenArray
    echo t.get("B").toOpenArray

when false:
  block:
    var
      db = trieDB newMemDB()
      t = initHexaryTrie(db)

    t.put("A", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    t.put("9", "b")
    t.del("9")

    echo "ROOT   ", t.rootHashHex.toLowerAscii
    echo "WANTED ", "d23786fb4a010da3ce639d66d5e904a11dbc02746d1ce25029e53290cabf28ab"

    echo t.get("A").toOpenArray

when false:
  block:
    var
      db = trieDB newMemDB()
      t = initHexaryTrie(db)

    t.put("do", "verb");
    t.put("ether", "wookiedoo");
    t.put("horse", "stallion");
    t.put("shaman", "horse")
    t.put("doge", "coin");
    t.del("ether");
    t.put("dog", "puppy");
    t.del("shaman")

    echo "ROOT   ", t.rootHashHex.toLowerAscii
    echo "WANTED ", "5991bb8c6514148a29db676a14ac506cd2cd5775ace63c30a4fe457715e9ac84"

when false:
  block:
    var
      db = trieDB newMemDB()
      t = initHexaryTrie(db)

    t.put("do", "verb");
    t.put("ether", "wookiedoo");
    t.put("horse", "stallion");
    t.put("shaman", "horse")
    t.put("doge", "coin");
    t.del("ether");
    t.put("dog", "puppy");
    t.del("shaman")

    echo "ROOT   ", t.rootHashHex.toLowerAscii
    echo "WANTED ", "5991bb8c6514148a29db676a14ac506cd2cd5775ace63c30a4fe457715e9ac84"

when false:
  block:
    var
      db = trieDB newMemDB()
      t = SecureHexaryTrie initHexaryTrie(db)

    t.put("A", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");

    echo "ROOT   ", t.rootHashHex.toLowerAscii
    echo "WANTED ", "e9e2935138352776cad724d31c9fa5266a5c593bb97726dd2a908fe6d53284df"

when false:
  block:
    var
      db = trieDB newMemDB()
      t = initHexaryTrie(db)

    t.put("do", "verb");
    t.put("horse", "stallion");
    t.put("doge", "coin");
    t.put("dog", "puppy")

    echo "ROOT   ", t.rootHashHex.toLowerAscii
    echo "WANTED ", "5991bb8c6514148a29db676a14ac506cd2cd5775ace63c30a4fe457715e9ac84"

when false:
  block:
    var
      db = trieDB newMemDB()
      t = initHexaryTrie(db)

    t.put("doe", "reindeer");
    t.put("dog", "puppy");
    t.put("dogglesworth", "cat");

    echo "ROOT   ", t.rootHashHex.toLowerAscii
    echo "WANTED ", "8aad789dff2f538bca5d8ea56e8abe10f4c7ba3a5dea95fea4cd6e7c3a1168d3"

