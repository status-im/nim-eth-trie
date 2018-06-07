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
  ethereum_trie/nodes, test_utils

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

proc test_binary_trie_node_parsing() =
  var x = 0
  for c in parseNodeData:
    let input = toBytesRange(c[0])
    let node = c[1]
    let output = (TrieNodeType(node[0]), toBytesRange(node[1]), toBytesRange(node[2])).TrieNode
    try:
      let res = parseNode(input)
    except InvalidNode as E:
      discard
    except:
      doAssert(false)
    inc x

test_binary_trie_node_parsing()
