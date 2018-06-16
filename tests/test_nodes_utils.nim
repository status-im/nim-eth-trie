#[
import
  pytest, trie.exceptions, trie.utils.nodes

proc testGetCommonPrefixLength*(left: [list, T0]; right: [list, T0]; expected: int): void =
  var actualA = getCommonPrefixLength(left, right)
  var actualB = getCommonPrefixLength(right, left)
  nil

proc testGetCommonPrefixLength*(left: [list, T0]; right: seq[int]; expected: int): void =
  var actualA = getCommonPrefixLength(left, right)
  var actualB = getCommonPrefixLength(right, left)
  nil

proc testGetCommonPrefixLength*(left: seq[int]; right: seq[int]; expected: int): void =
  var actualA = getCommonPrefixLength(left, right)
  var actualB = getCommonPrefixLength(right, left)
  nil

proc testConsumeCommonPrefix*(left: [list, T0]; right: [list, T0];
                             expected: ([list, T0], [list, T0], [list, T0])): void =
  var actualA = consumeCommonPrefix(left, right)
  var actualB = consumeCommonPrefix(right, left)
  var expectedB = (expected[0], expected[2], expected[1])
  nil
  nil

proc testConsumeCommonPrefix*(left: [list, T0]; right: seq[int];
                             expected: ([list, T0], [list, T0], seq[int])): void =
  var actualA = consumeCommonPrefix(left, right)
  var actualB = consumeCommonPrefix(right, left)
  var expectedB = (expected[0], expected[2], expected[1])
  nil
  nil

proc testConsumeCommonPrefix*(left: seq[int]; right: seq[int];
                             expected: (seq[int], [list, T0], [list, T0])): void =
  var actualA = consumeCommonPrefix(left, right)
  var actualB = consumeCommonPrefix(right, left)
  var expectedB = (expected[0], expected[2], expected[1])
  nil
  nil

proc testConsumeCommonPrefix*(left: seq[int]; right: seq[int];
                             expected: (seq[int], [list, T0], seq[int])): void =
  var actualA = consumeCommonPrefix(left, right)
  var actualB = consumeCommonPrefix(right, left)
  var expectedB = (expected[0], expected[2], expected[1])
  nil
  nil

proc testConsumeCommonPrefix*(left: seq[int]; right: seq[int];
                             expected: (seq[int], seq[int], seq[int])): void =
  var actualA = consumeCommonPrefix(left, right)
  var actualB = consumeCommonPrefix(right, left)
  var expectedB = (expected[0], expected[2], expected[1])
  nil
  nil
]#

import
  ethereum_trie/nodes, test_utils, rlp/types, unittest, strutils

const
  commonPrefixData = [
    (@[], @[], 0),
    (@[], @[1.byte], 0),
    (@[1.byte], @[1.byte], 1),
    (@[1.byte], @[1.byte, 1.byte], 1),
    (@[1.byte, 2.byte], @[1.byte, 1.byte], 1),
    (@[1.byte, 2.byte, 3.byte, 4.byte, 5.byte, 6.byte], @[1.byte, 2.byte, 3.byte, 5.byte, 6.byte], 3)
  ]

suite "binary trie nodes utils":

  test "get common prefix length":
    for c in commonPrefixData:
      let actual_a = getCommonPrefixLength(c[0], c[1])
      let actual_b = getCommonPrefixLength(c[1], c[0])
      let expected = c[2]
      check actual_a == actual_b
      check actual_a == expected

  const
    None = ""
    parseNodeData = {
      "\x00\x03\x04\x05\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p":
        (0, "\x00\x00\x01\x01\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
      "\x01\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p":
        (1, "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
      "\x02value": (2, None, "value"),
      "": (0, None, None),
      "\x00\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p": (0, None, None),
      "\x01\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p": (0, None, None),
      "\x01\x02\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p":
        (0, None, None),
      "\x02": (0, None, None),
      "\x03": (0, None, None)
    }

  test "node parsing":
    var x = 0
    for c in parseNodeData:
      let input = toBytesRange(c[0])
      let node = c[1]
      let kind = TrieNodeKind(node[0])
      try:
        let res = parseNode(input)
        check(kind == res.kind)
        case res.kind
        of KV_TYPE:
          check(res.keyPath == toBytesRange(node[1]))
          check(res.child == toBytesRange(node[2]))
        of BRANCH_TYPE:
          check(res.leftChild == toBytesRange(node[2]))
          check(res.rightChild == toBytesRange(node[2]))
        of LEAF_TYPE:
          check(res.value == toBytesRange(node[2]))
      except InvalidNode as E:
        discard
      except:
        echo getCurrentExceptionMsg()
        check(false)
      inc x

  const
    kvData = [
      ("\x00", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "\x00\x10\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
      (""    , "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
      ("\x00", "\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
      ("\x01", "\x00\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
      ("\x02", "", None)
    ]

  test "kv node encoding":
    for c in kvData:
      let keyPath = b(c[0])
      let node    = toBytesRange(c[1])
      let output  = b(c[2])

      try:
        check output == encodeKVNode(keyPath, node)
      except ValidationError as E:
        discard
      except:
        check(getCurrentExceptionMsg() == "len(childHash) == 32 ")

  const
    branchData = [
      ("\xc8\x9e\xfd\xaaT\xc0\xf2\x0cz\xdfa(\x82\xdf\tP\xf5\xa9Qc~\x03\x07\xcd\xcbLg/)\x8b\x8b\xc6", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p",
        "\x01\xc8\x9e\xfd\xaaT\xc0\xf2\x0cz\xdfa(\x82\xdf\tP\xf5\xa9Qc~\x03\x07\xcd\xcbLg/)\x8b\x8b\xc6\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
      ("", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
      ("\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "\x01", None),
      ("\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "12345", None),
      (repeat('\x01', 33), repeat('\x01', 32), None),
    ]

  test "branch node encode":
    for c in branchData:
      let left   = toBytesRange(c[0])
      let right  = toBytesRange(c[1])
      let output = b(c[2])

      try:
        check output == encodeBranchNode(left, right)
      except AssertionError as E:
        check (E.msg == "len(leftChildHash) == 32 ") or (E.msg == "len(rightChildHash) == 32 ")
      except:
        check(false)

  const
    leafData = [
      ("\x03\x04\x05", "\x02\x03\x04\x05"),
      ("", None)
    ]

  test "leaf node encode":
    for c in leafData:
      try:
        check b(c[1]) == encodeLeafNode(toBytesRange(c[0]))
      except ValidationError as E:
        discard
      except:
        check(false)
