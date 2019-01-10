mode = ScriptMode.Verbose

packageName   = "eth_trie"
version       = "1.0.0"
author        = "Status Research & Development GmbH"
description   = "Merkle Patricia Tries as specified by Ethereum"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 0.18.1",
         "rlp",
         "nimcrypto",
         "ranges",
         "rocksdb"

task test, "test debug mode":
  --hints: off
  --debuginfo
  --path: "."
  --run
  setCommand "c", "tests/all.nim"

task testRelease, "test release mode":
  switch("define", "release")
  testTask()
