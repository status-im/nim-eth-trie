mode = ScriptMode.Verbose

packageName   = "ethereum-trie"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Merkle Patricia Tries as specified by Ethereum"
license       = "Apache2"
skipDirs      = @["tests"]

requires "nim >= 0.17.0", "rlp >= 0.2.0", "keccak-tiny >= 0.1.0"

--path:"nim-rlp"
--path:"rlp"
--path:"keccak-tiny"

proc configForTests() =
  --hints: off
  --debuginfo
  --path: "."
  --run

task test, "run CPU tests":
  configForTests()
  setCommand "c", "tests/all.nim"

