
import
  tables, py2nim_helpers, math, sequtils, algorithm, strutils

const
  BLANKNODE = cstring""
  BLANKHASH = cstring"\\xc5\\xd2F\\x01\\x86\\xf7#<\\x92~}\\xb2\\xdc\\xc7\\x03\\xc0\\xe5\\x00\\xb6S\\xca\\x82';{\\xfa\\xd8\\x04]\\x85\\xa4p"
  BLANKNODEHASH = cstring"V\\xe8\\x1f\\x17\\x1b\\xccU\\xa6\\xff\\x83E\\xe6\\x92\\xc0\\xf8n[H\\xe0\\x1b\\x99l\\xad\\xc0\\x01b/\\xb5\\xe3c\\xb4!"
  NIBBLESLOOKUP = cstring"0123456789abcdef".mapTable(v: idx)
  NIBBLETERMINATOR = 16
  HPFLAG2 = 2
  HPFLAG0 = 0
  NODETYPEBLANK = 0
  NODETYPELEAF = 1
  NODETYPEEXTENSION = 2
  NODETYPEBRANCH = 3
  EXP = tuple(reversed(tuple(range(8).mapIt(2 ^ it))))
  TWOBITS = @[cstring(@[0.char, 0.char].join("")),
            cstring(@[0.char, 1.char].join("")),
            cstring(@[1.char, 0.char].join("")),
            cstring(@[1.char, 1.char].join(""))]
  PREFIX00 = cstring(@[0.char, 0.char].join(""))
  PREFIX100000 = cstring(@[1.char, 0.char, 0.char, 0.char, 0.char, 0.char].join(""))
  KVTYPE = 0
  BRANCHTYPE = 1
  LEAFTYPE = 2
  BINARYTRIENODETYPES = (0, 1, 2)
  KVTYPEPREFIX = cstring(@[0.char].join(""))
  BRANCHTYPEPREFIX = cstring(@[1.char].join(""))
  LEAFTYPEPREFIX = cstring(@[2.char].join(""))
  BYTE1 = cstring(@[1.char].join(""))
  BYTE0 = cstring(@[0.char].join(""))
