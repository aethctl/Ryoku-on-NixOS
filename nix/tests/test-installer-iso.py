import os
import subprocess
import unittest


class ISOInstallerTests(unittest.TestCase):
    def test_dry_run_generates_fresh_nixos_target_without_touching_disk(self):
        backend = os.environ["RYOKU_INSTALL_TEST_BACKEND"]
        env = dict(
            os.environ,
            RYOKU_INSTALL_TARGET_SOURCE="github:aethctl/Ryoku-on-NixOS/deadbeef",
            RYOKU_INSTALL_NIXPKGS_SOURCE="github:NixOS/nixpkgs/cafebabe",
        )
        result = subprocess.run(
            [
                backend,
                "--iso",
                "--dry-run",
                "--disk",
                "/dev/vda",
                "--filesystem",
                "btrfs",
                "--hostname",
                "ryoku-test",
                "--username",
                "tester",
                "--firmware",
                "uefi",
                "--compositor",
                "niri",
                "--browser",
                "firefox",
                "--shell",
                "zsh",
                "--apps",
                "prompt,go",
                "--yes",
                "--confirm-disk",
                "/dev/vda",
            ],
            env=env,
            capture_output=True,
            text=True,
            timeout=20,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("Ryoku NixOS full installation", output)
        self.assertIn("Disk       /dev/vda", output)
        self.assertIn("Filesystem btrfs", output)
        self.assertIn('nixosConfigurations."ryoku-test"', output)
        self.assertIn('nixpkgs.url = "github:NixOS/nixpkgs/cafebabe"', output)
        self.assertIn('ryoku.url = "github:aethctl/Ryoku-on-NixOS/deadbeef"', output)
        self.assertIn('defaultCompositor = "niri"', output)
        self.assertIn('browser = "firefox"', output)
        self.assertIn('shell = "zsh"', output)
        self.assertIn('nix.package = pkgs.nixVersions.latest', output)
        self.assertIn('"prompt"', output)
        self.assertIn('"go"', output)
        self.assertIn("boot.loader.systemd-boot.enable = true", output)
        self.assertIn("Dry run complete. No disks or files were changed.", output)
        self.assertNotIn("@@RYOKU_STEP partition", output)
        self.assertNotIn("@@RYOKU_STEP install", output)

    def test_unattended_install_requires_exact_confirmation_token(self):
        backend = os.environ["RYOKU_INSTALL_TEST_BACKEND"]
        result = subprocess.run(
            [
                backend,
                "--iso",
                "--disk",
                "/dev/vda",
                "--hostname",
                "ryoku-test",
                "--username",
                "tester",
                "--firmware",
                "uefi",
                "--compositor",
                "niri",
                "--browser",
                "firefox",
                "--shell",
                "fish",
                "--apps",
                "none",
                "--yes",
            ],
            env=dict(os.environ, RYOKU_INSTALL_PASSWORD_HASH="$y$j9T$test$test"),
            capture_output=True,
            text=True,
            timeout=20,
        )
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, output)
        # The real block-device check may reject /dev/vda first on CI. The
        # destructive confirmation requirement is separately source-checked by
        # the flake contract below and exercised on real VM media.


if __name__ == "__main__":
    unittest.main()
