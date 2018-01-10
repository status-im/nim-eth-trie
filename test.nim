
import
  pytest, os

proc test*(): void =
  pytest.main(@[os.path.abspath(os.path.dirname(__file__)) & "/tests"])

when isMainModule:
  test()
