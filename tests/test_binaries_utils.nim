import
  ethereum_trie/memdb
  
@given(value=st.binary(min_size=0, max_size=1024))
def test_round_trip_bin_encoding(value):
    value_as_binaries = encode_to_bin(value)
    result = decode_from_bin(value_as_binaries)
    assert result == value


@given(value=st.lists(elements=st.integers(0, 1), min_size=0, max_size=1024))
def test_round_trip_bin_keypath_encoding(value):
    value_as_bin_keypath = encode_from_bin_keypath(bytes(value))
    result = decode_to_bin_keypath(value_as_bin_keypath)
    assert result == bytes(value)  
  
  var ascii = @['A'.byte, 'S'.byte, 'C'.byte, 'I'.byte, 'I'.byte]
  var bits = encode_to_bin(ascii.toRange)
  var output = ""
  for c in BytesRange(bits):
    output.add c.char
  echo output

  var s = decode_from_bin(bits)
  var str = ""
  for c in s:
    str.add char(c)
  echo str

  echo encode_from_bin_keypath(bits)