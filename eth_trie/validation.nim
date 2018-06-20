import
  constants, exceptions

proc validateLength*(value: string; length: int): void =
  if len(value) != length:
    raise newException(ValidationError, "Value is of length {0}.  Must be {1}".format(
        len(value), length))

