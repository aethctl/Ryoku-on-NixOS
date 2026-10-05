# Ryoku-on-NixOS ISO Configs

A flake-based NixOS configuration for [Ryoku-on-NixOS](https://github.com/aethctl/Ryoku-on-NixOS) ISO. Everything lives in `/etc/nixos`.

## Structure

| File | Purpose |
|------|---------|
| `flake.nix` | Entry point. Pulls `nixpkgs` (unstable) and the Ryoku flake, and loads the modules. |
| `configuration.nix` | Main system settings: boot, hostname, networking, timezone, locale, keymap, user, garbage collection, and fish helper commands. |
| `pkgs.nix` | List of installed system packages. |
| `nvidia.nix` | Graphics config. |
| `ryoku.nix` | Enables Ryoku. Managed by ryoku, **don't edit**. |
| `modules/module-example.nix` | Empty template for your own modules. |

## Applying Changes

After editing any file, rebuild:

```sh
rebuild
```

This is a fish shortcut for `sudo nixos-rebuild switch --flake /etc/nixos#nixos`.

## Fish Shortcuts

| Command | What it does |
|---------|--------------|
| `rebuild` | Rebuild and switch to the new configuration |
| `update` | Update Ryoku, channels and flake inputs, then rebuild |
| `clean` | Run garbage collection (`nix-collect-garbage -d`) |
| `nixos` | `cd` into `/etc/nixos` |
| `configuration` / `flake` / `pkgs` | Open the respective file in neovim as root |

## Common Edits

**Add packages** — in `pkgs.nix`, add the name to `environment.systemPackages` (search at [search.nixos.org/packages](https://search.nixos.org/packages)):

```nix
environment.systemPackages = with pkgs; [
  firefox
  vlc
];
```

**Change timezone, locale or keyboard layout** — in `configuration.nix`, edit `time.timeZone` (default `America/New_York`), `i18n.defaultLocale` and the `LC_*` entries (default `en_US.UTF-8`), and `services.xserver.xkb.layout` (default `us`).

**Change hostname** — edit `networking.hostName` in `configuration.nix`. If you change it, also update `nixosConfigurations.nixos` in `flake.nix` and the `#nixos` in the fish shortcuts.

**Add your own module:**

1. Copy `modules/module-example.nix` to `modules/my-module.nix`.
2. Add your options inside it, e.g. `services.flatpak.enable = true;`.
3. Import it in `configuration.nix`:
   ```nix
   imports = [
     ./hardware-configuration.nix
     ./pkgs.nix
     ./nvidia.nix
     ./modules/my-module.nix
   ];
   ```
4. Run `rebuild`.

## Useful Defaults to Know

- Unfree packages are allowed.
- Flakes and `nix-command` are enabled.
- Garbage collection runs weekly and removes generations older than 14 days; the store is also optimised weekly.
- Bootloader is systemd-boot (UEFI).
- Default user is `ryoku` (groups: `networkmanager`, `wheel`).

## Help

- NixOS options: [search.nixos.org/options](https://search.nixos.org/options) or `nixos-help`
- Ryoku-on-NixOS: [Discord](https://discord.gg/DdrpX5ksPK)
