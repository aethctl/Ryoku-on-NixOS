import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import termios
import tempfile
import time

import runpy

flake = runpy.run_path(str(Path(__file__).with_name("test-installer-transaction.py")))["FLAKE"]
binary = os.environ["RYOKU_INSTALL_TEST_BINARY"]

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / "flake.nix").write_text(flake)
    (root / "configuration.nix").write_text("{ ... }: { system.stateVersion = \"26.05\"; }\n")
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.execv(binary, [binary, "--flake", directory + "#host", "--dry-run"])
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 112, 0, 0))
    output = bytearray()

    def pump(seconds):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if select.select([fd], [], [], 0.05)[0]:
                try:
                    data = os.read(fd, 65536)
                except OSError:
                    return
                output.extend(data)
                if b"\x1b[6n" in data:
                    os.write(fd, b"\x1b[1;1R")

    try:
        pump(2)
        for _ in range(6):
            os.write(fd, b"\r")
            pump(0.5)
        pump(2)
        assert b"Dry run complete" in output, "Backend dry run did not complete"
        os.write(fd, b"\r")
        pump(1)
        done, status = os.waitpid(pid, os.WNOHANG)
        assert done, "TUI did not close after success"
        pid = None
        assert os.waitstatus_to_exitcode(status) == 0
        assert (root / "flake.nix").read_text() == flake
        assert not (root / "ryoku.nix").exists()
        print("Packaged TUI and backend dry run passed. Fixture unchanged.")
    finally:
        if pid:
            os.kill(pid, signal.SIGTERM)
            os.waitpid(pid, 0)
        os.close(fd)
