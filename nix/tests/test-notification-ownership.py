#!/usr/bin/env python3
import os
from pathlib import Path
import unittest


MODULE = Path(
    os.environ.get(
        "RYOKU_NIX_MODULE",
        Path(__file__).parents[1] / "modules/ryoku.nix",
    )
)


class NotificationOwnershipTest(unittest.TestCase):
    def test_shell_retires_stale_mako_before_start(self):
        text = MODULE.read_text()
        shell = text.split("systemd.user.services.ryoku-shell = {", 1)[1]
        shell = shell.split("\n    };\n  };", 1)[0]

        stop = '"-${pkgs.systemd}/bin/systemctl --user stop mako.service"'
        kill = '"-${pkgs.procps}/bin/pkill -f /bin/mako([[:space:]]|$)"'
        qylock = '"${ryokuHelpers}/bin/ryoku-qylock-activate"'

        self.assertIn(stop, shell)
        self.assertIn(kill, shell)
        self.assertIn(qylock, shell)
        self.assertLess(shell.index(stop), shell.index(qylock))
        self.assertLess(shell.index(kill), shell.index(qylock))


if __name__ == "__main__":
    unittest.main()
