mode = ScriptMode.Verbose

packageName   = "eth_trie"
version       = "1.0.0"
author        = "Status Research & Development GmbH"
description   = "Merkle Patricia Tries as specified by Ethereum"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 0.18.1",
         "rlp",
         "eth_common",
         "nimcrypto",
         "ranges"

proc configForTests() =
  --hints: off
  --debuginfo
  --path: "."
  --run

task test, "run CPU tests":
  configForTests()
  setCommand "c", "tests/all.nim"

