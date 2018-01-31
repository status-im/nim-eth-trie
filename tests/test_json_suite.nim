import
  os, json, tables, sequtils, strutils,
  rlp/types, ethereum_trie, ethereum_trie/memdb

proc hexRepr*(bytes: BytesRange): string =
  result = newStringOfCap(bytes.len * 2)
  for byte in bytes:
    result.add(toHex(int(byte), 2).toLowerAscii)

proc `==`(lhs: JsonNode, rhs: string): bool =
  lhs.kind == JString and lhs.str == rhs

proc toBytesRange(str: string): BytesRange =
  var s = newSeq[byte](str.len)
  for i in 0 ..< str.len:
    s[i] = byte(str[i])
  result = initBytesRange(s)

proc runTests*(filename: string) =
  let js = json.parseFile(filename)

  for testname, testdata in js:
    template testStatus(status: string) =
      echo status, " ", filename, " :: ", testname

    template invalidTest =
      testStatus "IGNORED"
      writeStackTrace()
      continue

    let
      input = testdata{"in"}
      root = testdata{"root"}

    var
      db = newMemDB()
      t = initTrie(db)

    if input.isNil or root.isNil or root.kind != JString:
      invalidTest()

    case input.kind
    of JArray:
      for pair in input.elems:
        if pair.kind != JArray or pair.elems.len != 2:
          invalidTest()
        let
          k = pair.elems[0]
          v = pair.elems[1]
        if k.kind == JString:
          case v.kind
          of JString:
            t.put(k.str.toBytesRange, v.str.toBytesRange)
          of JNull:
            t.del(k.str.toBytesRange)
          else:
            invalidTest()
        else:
          invalidTest()

    of JObject:
      for k, v in input.fields:
        case v.kind
        of JString:
          t.put(k.toBytesRange, v.str.toBytesRange)
        of JNull:
          t.del(k.toBytesRange)
        else:
          invalidTest()
    else:
      invalidTest()

    let
      expectedRoot = root.str.substr(2)
      actualRoot = t.rootHashHex
    if expectedRoot == actualRoot:
      testStatus "OK"
    else:
      testStatus "FAILED"
      echo "EXPECTED ROOT: ", expectedRoot
      echo "ACTUAL   ROOT: ", actualRoot

for file in walkDirRec("tests/cases"):
  if file.endsWith("json"):
    runTests(file)

