
import
  trie.constants, trie.exceptions

proc validateIsBytes*(value: cstring): void =
  if not(value of bytes):
    raise newException(ValidationError, "Value is not of type `bytes`: got \'{0}\'".format(
        type(value)))

proc validateIsBytes*(value: int): void =
  if not(value of bytes):
    raise newException(ValidationError, "Value is not of type `bytes`: got \'{0}\'".format(
        type(value)))

proc validateIsBytes*(value: range): void =
  if not(value of bytes):
    raise newException(ValidationError, "Value is not of type `bytes`: got \'{0}\'".format(
        type(value)))

proc validateIsBytes*(value: seq[int]): void =
  if not(value of bytes):
    raise newException(ValidationError, "Value is not of type `bytes`: got \'{0}\'".format(
        type(value)))

proc validateLength*(value: cstring; length: int): void =
  if len(value) != length:
    raise newException(ValidationError, "Value is of length {0}.  Must be {1}".format(
        len(value), length))

proc validateIsNode*(node: seq[cstring]): void =
  if node == BLANKNODE:
    return nil
  elif len(node) == 2:
    (key, value) = node
    validateIsBytes(key)
    if isinstance(value, list):
      validateIsNode(value)
    else:
      validateIsBytes(value)
  elif len(node) == 17:
    validateIsBytes(node[16])
    for subNode in node[0 .. ^1]:
      if subNode == BLANKNODE:
        continue
      elif isinstance(subNode, list):
        validateIsNode(subNode)
      else:
        validateIsBytes(subNode)
        validateLength(subNode, 32)
  else:
    raise ValidationError("Invalid Node: {0}".format(node))
  
proc validateIsBinNode*(node: cstring): void =
  if node == BLANKHASH or node[0] in BINARYTRIENODETYPES:
    return nil
  else:
    raise ValidationError("Invalid Node: {0}".format(node))
  
