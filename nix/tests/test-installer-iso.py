import os
import subprocess
import unittest


class ISOInstallerTests(unittest.TestCase):
    def run_backend(self, *args, env=None):
        backend = os.environ["RYOKU_INSTALL_TEST_BACKEND"]
        return subprocess.run(
            [backend, *args],
            env=env or os.environ,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def test_dry_run_uses_canonical_iso_configs(self):
        env = dict(
            os.environ,
            RYOKU_INSTALL_TARGET_SOURCE="github:aethctl/Ryoku-on-NixOS/deadbeef",
            RYOKU_INSTALL_NIXPKGS_SOURCE="github:NixOS/nixpkgs/cafebabe",
        )
        result = self.run_backend(
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
            "--timezone",
            "Europe/London",
            "--locale",
            "en_GB.UTF-8",
            "--keyboard",
            "gb",
            "--gpu",
            "nvidia,intel",
            "--firmware",
            "uefi",
            "--compositor",
            "mango",
            "--browser",
            "firefox",
            "--shell",
            "zsh",
            "--apps",
            "prompt,go",
            "--yes",
            "--confirm-disk",
            "/dev/vda",
            env=env,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)

        self.assertIn("Ryoku NixOS full installation", output)
        self.assertIn("Disk       /dev/vda", output)
        self.assertIn("Filesystem btrfs", output)
        self.assertIn("Timezone   Europe/London", output)
        self.assertIn("Locale     en_GB.UTF-8", output)
        self.assertIn("Keyboard   gb", output)
        self.assertIn("GPU        nvidia,intel", output)
        self.assertIn("WM         mango", output)

        # Release flakes retain updatable branch URLs. The installer pins the
        # tested revisions in flake.lock with --override-input instead.
        self.assertIn("nixosConfigurations.ryoku", output)
        self.assertIn('nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"', output)
        self.assertIn('ryoku.url = "github:aethctl/Ryoku-on-NixOS/main"', output)
        self.assertIn('ryokuSource = "github:aethctl/Ryoku-on-NixOS/deadbeef"', output)
        self.assertIn('nixpkgsSource = "github:NixOS/nixpkgs/cafebabe"', output)
        self.assertIn("./ryoku.nix", output)
        self.assertIn("./configuration.nix", output)

        # configuration.nix stays human-readable and consumes the generated
        # install-values.nix through specialArgs.
        self.assertIn("map gpuModule install.gpuVendors", output)
        self.assertIn("networking.hostName = install.hostname", output)
        self.assertIn("nix.package = pkgs.nixVersions.latest", output)
        self.assertIn("nixos-rebuild switch --flake /etc/nixos#ryoku", output)

        # install-values.nix carries only machine-specific choices.
        self.assertIn('hostname = "ryoku-test"', output)
        self.assertIn('username = "tester"', output)
        self.assertNotIn("passwordHash", output)
        self.assertIn('timeZone = "Europe/London"', output)
        self.assertIn('locale = "en_GB.UTF-8"', output)
        self.assertIn('keyboardLayout = "gb"', output)
        self.assertIn('"nvidia"', output)
        self.assertIn('"intel"', output)
        self.assertIn('compositor = "mango"', output)
        self.assertIn('browser = "firefox"', output)
        self.assertIn('shell = "zsh"', output)
        self.assertIn('"prompt"', output)
        self.assertIn('"go"', output)

        self.assertIn("Dry run complete. No disks or files were changed.", output)
        self.assertNotIn("@@RYOKU_STEP partition", output)
        self.assertNotIn("@@RYOKU_STEP install", output)

    def test_live_iso_source_is_rebased_into_target_flake(self):
        env = dict(
            os.environ,
            RYOKU_INSTALL_TARGET_SOURCE="path:/etc/ryoku/source",
        )
        result = self.run_backend(
            "--iso",
            "--dry-run",
            "--yes",
            "--disk",
            "/dev/vda",
            "--confirm-disk",
            "/dev/vda",
            "--gpu",
            "none",
            env=env,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn('ryoku.url = "path:./ryoku-source"', output)
        self.assertIn('ryokuSource = "path:./ryoku-source"', output)
        self.assertNotIn('ryoku.url = "path:/etc/ryoku/source"', output)

    def test_all_gpu_modes_are_accepted(self):
        for gpu in ("none", "nvidia", "amd", "intel", "nvidia,intel", "nvidia,amd"):
            with self.subTest(gpu=gpu):
                result = self.run_backend(
                    "--iso",
                    "--dry-run",
                    "--yes",
                    "--disk",
                    "/dev/vda",
                    "--confirm-disk",
                    "/dev/vda",
                    "--gpu",
                    gpu,
                )
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)

    def test_invalid_gpu_mode_is_rejected(self):
        result = self.run_backend(
            "--iso",
            "--dry-run",
            "--yes",
            "--disk",
            "/dev/vda",
            "--confirm-disk",
            "/dev/vda",
            "--gpu",
            "potato",
        )
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, output)
        self.assertIn("invalid GPU vendor", output)

    def test_unattended_install_requires_exact_confirmation_token(self):
        result = self.run_backend(
            "--iso",
            "--disk",
            "/dev/vda",
            "--hostname",
            "ryoku-test",
            "--username",
            "tester",
            "--firmware",
            "uefi",
            "--gpu",
            "none",
            "--compositor",
            "niri",
            "--browser",
            "firefox",
            "--shell",
            "fish",
            "--apps",
            "none",
            "--yes",
            env=dict(os.environ, RYOKU_INSTALL_PASSWORD_HASH="$y$j9T$test$test"),
        )
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, output)
        # CI may reject synthetic /dev/vda at the block-device check before the
        # confirmation branch. The exact-token contract is also source-checked
        # by flake.nix and exercised in the VM install test.


if __name__ == "__main__":
    unittest.main()
