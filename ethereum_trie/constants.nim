import
  tables, py2nim_helpers, math, sequtils, algorithm, strutils

const
  BLANK_STRING_HASH = "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
  BLANK_RLP_HASH = "56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"

  NIBBLESLOOKUP = string"0123456789abcdef".mapTable(v: idx)
  NIBBLETERMINATOR = 16
  HPFLAG2 = 2
  HPFLAG0 = 0
  
  NODETYPE_BLANK = 0
  NODETYPE_LEAF = 1
  NODETYPE_EXTENSION = 2
  NODETYPE_BRANCH = 3
  
  EXP = tuple(reversed(tuple(range(8).mapIt(2 ^ it))))
  TWOBITS = @[string(@[0.char, 0.char].join("")),
            string(@[0.char, 1.char].join("")),
            string(@[1.char, 0.char].join("")),
            string(@[1.char, 1.char].join(""))]
  PREFIX00 = string(@[0.char, 0.char].join(""))
  PREFIX100000 = string(@[1.char, 0.char, 0.char, 0.char, 0.char, 0.char].join(""))
  KVTYPE = 0
  BRANCHTYPE = 1
  LEAFTYPE = 2
  BINARYTRIENODETYPES = (0, 1, 2)
  KVTYPEPREFIX = string(@[0.char].join(""))
  BRANCHTYPEPREFIX = string(@[1.char].join(""))
  LEAFTYPEPREFIX = string(@[2.char].join(""))
  BYTE1 = string(@[1.char].join(""))
  BYTE0 = string(@[0.char].join(""))
