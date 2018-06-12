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
    (@[], @[1], 0),
    (@[1], @[1], 1),
    (@[1], @[1, 1], 1),
    (@[1, 2], @[1, 1], 1),
    (@[1, 2, 3, 4, 5, 6], @[1, 2, 3, 5, 6], 3)
  ]

test "get common prefix length":
  for c in commonPrefixData:
    let actual_a = getCommonPrefixLength(c[0].toBytesRange, c[1].toBytesRange)
    let actual_b = getCommonPrefixLength(c[1].toBytesRange, c[0].toBytesRange)
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

test "binary trie node parsing":
  var x = 0
  for c in parseNodeData:
    let input = toBytesRange(c[0])
    let node = c[1]
    let kind = TrieNodeKind(node[0])
    let one = toBytesRange(node[1])
    let two = toBytesRange(node[2])
    try:
      let res = parseNode(input)
      doAssert(kind == res.kind)
      case res.kind
      of KV_TYPE:
        check(res.keyPath == one)
        check(res.child == two)
      of BRANCH_TYPE:
        check(res.leftChild == one)
        check(res.rightChild == two)
      of LEAF_TYPE:
        check(res.value == two)
    except InvalidNode as E:
      discard
    except:
      echo getCurrentExceptionMsg()
      doAssert(false)
    inc x

const
  kvData = [
    ("\x00", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "\x00\x10\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
    (""    , "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
    ("\x00", "\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
    ("\x01", "\x00\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
    ("\x02", "", None)
  ]

test "binary trie kv node encoding":
  for c in kvData:
    let keyPath = b(c[0])
    let node    = b(c[1])
    let output  = b(c[2])

    try:
      check output == encodeKVNode(keyPath, node)
    except ValidationError as E:
      discard
    except:
      check(getCurrentExceptionMsg() == "len(childNodeHash) == 32 ")

const
  branchData = [
    ("\xc8\x9e\xfd\xaaT\xc0\xf2\x0cz\xdfa(\x82\xdf\tP\xf5\xa9Qc~\x03\x07\xcd\xcbLg/)\x8b\x8b\xc6", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p",
       "\x01\xc8\x9e\xfd\xaaT\xc0\xf2\x0cz\xdfa(\x82\xdf\tP\xf5\xa9Qc~\x03\x07\xcd\xcbLg/)\x8b\x8b\xc6\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
    ("", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
    ("\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "\x01", None),
    ("\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "12345", None),
    (repeat('\x01', 33), repeat('\x01', 32), None),
  ]

test "binary trie branch node encode":
  for c in branchData:
    let left   = b(c[0])
    let right  = b(c[1])
    let output = b(c[2])

    try:
      check output == encodeBranchNode(left, right)
    except AssertionError as E:
      check (E.msg == "len(leftChildNodeHash) == 32 ") or (E.msg == "len(rightChildNodeHash) == 32 ")
    except:
      doAssert(false)

const
  leafData = [
    ("\x03\x04\x05", "\x02\x03\x04\x05"),
    ("", None)
  ]

test "binary trie leaf node encode":
  for c in leafData:
    try:
      check b(c[1]) == encodeLeafNode(toBytesRange(c[0]))
    except ValidationError as E:
      discard
    except:
      doAssert(false)
