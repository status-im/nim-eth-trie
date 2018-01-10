
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

