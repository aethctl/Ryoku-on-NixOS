# Automation notes for Ryoku on NixOS

This file gives automated coding tools repository-specific context. Human
contribution policy lives in [`CONTRIBUTING.md`](CONTRIBUTING.md); port ownership
and sync policy live in [`docs/maintenance.md`](docs/maintenance.md).

## Read first

1. `CONTRIBUTING.md`
2. `docs/maintenance.md`
3. `docs/structure.md`
4. `docs/nixos.md`

Do not infer current behavior from the upstream Arch tree when NixOS has an
explicit implementation under `nix/`.

## Repository boundary

- `ryoku/`: shared Ryoku desktop and applications.
- `nix/`: NixOS packages, module, installer, materializer and runtime bridges.
- `flake.nix`: public Nix interface and build checks.
- `tests/` and `nix/tests/`: validation.
- `installation/`, `system/`, `release/`: upstream Arch reference/parity unless a
  shared change genuinely belongs there.

Prefer the smallest host-specific seam. Do not duplicate a shared component into
`nix/` just to avoid understanding its interface.

## Change rules

- Search for the existing implementation before adding a second one.
- Keep unrelated cleanup out of functional patches.
- Preserve upstream behavior unless the NixOS host requires a difference.
- If a bug also affects upstream and the fix is portable, prepare the same fix
  for upstream rather than maintaining a Nix-only workaround.
- Do not turn runtime assumptions into hard-coded `/usr/bin`, Pacman/AUR or
  mutable-system paths on NixOS.
- Treat the Nix store and Home Manager-managed paths as immutable ownership
  boundaries.
- For ABI-sensitive Hyprland/portal/plugin work, use the package set owned by
  this flake unless the module deliberately exposes another contract.

## Validation

Start narrow, then widen:

```bash
bash -n path/to/script
qmllint path/to/file.qml
python3 nix/tests/test-ryoku-install-edit.py
nix build .#<affected-output>
nix flake check
```

Do not claim runtime behavior from a build alone. Display, compositor, GPU,
audio, portal, installer and update changes need a running-system test when
applicable.

## Commit and PR context

Use conventional commit subjects; legacy `[area]` prefixes are accepted but not
required. Keep the subject under 72 characters.

For user-visible changes, preserve:

```text
Note: New|Fixed|Removed: plain-language result
```

A pull request should explain the reason, ownership boundary, verification and
upstream applicability. Short evidence is better than a long generic summary.

## Generated or assisted code

Tooling may assist development, but it does not own the patch. Remove placeholder
text and conversational residue, understand the change, and report real
validation. Do not fabricate tests, runtime observations or upstream behavior.
