
import
  pytest, itertools, fnmatch, json, os, eth_utils, trie.hexary

iterator recursiveFindFiles*(baseDir: string; pattern: string): void =
  for dirpath, _ in os.walk(baseDir):
    for filename in filenames:
      if fnmatch.fnmatch(filename, pattern):
        yield os.path.join(dirpath, filename)

var ROOTPROJECTDIR = os.path.dirname(os.path.dirname(__file__))
var BASEFIXTUREPATH = os.path.join(ROOTPROJECTDIR, "fixtures", "TrieTests")
var FIXTURESPATHS = tuple(recursiveFindFiles(BASEFIXTUREPATH, "trietest.json"))
var RAWFIXTURES = tuple()        ## py2nim can't generate code for
                      ## GeneratorExp:
                      ##   Tuple:
                      ##     Call:
                      ##       Attribute:
                      ##         Attribute:
                      ##           Label(os)
                      ##           Str(path)
                      ##         Str(basename)
                      ##       Sequence:
                      ##         Label(fixture_path)
                      ##       Sequence:
                      ## 
                      ##     Call:
                      ##       Attribute:
                      ##         Label(json)
                      ##         Str(load)
                      ##       Sequence:
                      ##         Call:
                      ##           Label(open)
                      ##           Sequence:
                      ##             Label(fixture_path)
                      ##           Sequence:
                      ## 
                      ##       Sequence:
                      ## 
                      ##   Sequence:
                      ##     comprehension:
                      ##       Label(fixture_path)
                      ##       Label(FIXTURES_PATHS)
                      ##       Sequence:
                      ## 
                      ##       Int(0)
var FIXTURES = tuple()           ## py2nim can't generate code for
                   ## GeneratorExp:
                   ##   Tuple:
                   ##     Call:
                   ##       Attribute:
                   ##         Str({0}:{1})
                   ##         Str(format)
                   ##       Sequence:
                   ##         Label(fixture_filename)
                   ##         Label(key)
                   ##       Sequence:
                   ## 
                   ##     Call:
                   ##       Label(normalize_fixture)
                   ##       Sequence:
                   ##         Subscript:
                   ##           Label(fixtures)
                   ##           Index:
                   ##             Label(key)
                   ##       Sequence:
                   ## 
                   ##   Sequence:
                   ##     comprehension:
                   ##       Tuple:
                   ##         Label(fixture_filename)
                   ##         Label(fixtures)
                   ##       Label(RAW_FIXTURES)
                   ##       Sequence:
                   ## 
                   ##       Int(0)
                   ##     comprehension:
                   ##       Label(key)
                   ##       Call:
                   ##         Label(sorted)
                   ##         Sequence:
                   ##           Call:
                   ##             Attribute:
                   ##               Label(fixtures)
                   ##               Str(keys)
                   ##             Sequence:
                   ## 
                   ##             Sequence:
                   ## 
                   ##         Sequence:
                   ## 
                   ##       Sequence:
                   ## 
                   ##       Int(0)
