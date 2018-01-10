
import
  sha3

proc keccak*(value: cstring): cstring =
  return keccak256(value).digest()

