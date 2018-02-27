mode = ScriptMode.Verbose

packageName   = "ethereum_trie"
version       = "1.0.0"
author        = "Status Research & Development GmbH"
description   = "Merkle Patricia Tries as specified by Ethereum"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 0.17.0", "rlp >= 1.0.1", "keccak_tiny >= 0.1.0"

proc configForTests() =
  --hints: off
  --debuginfo
  --path: "."
  --run

task test, "run CPU tests":
  configForTests()
  setCommand "c", "tests/all.nim"

