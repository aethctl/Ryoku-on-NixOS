import runpy
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


class CursorReassertTest(unittest.TestCase):
    def test_recolor_reasserts_the_configured_cursor(self):
        root = Path(__file__).resolve().parents[2]
        script = root / "release/packages/ryoku-cursor-material/ryoku-cursor-material-recolor"
        recolor = runpy.run_path(str(script))
        with patch("subprocess.run") as run:
            recolor["apply_live"]()
        run.assert_called_once_with(
            ["ryoku", "wm", "act", "cursor.reassert"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


if __name__ == "__main__":
    unittest.main()
