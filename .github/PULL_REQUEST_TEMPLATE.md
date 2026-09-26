<!-- Keep the PR focused. See CONTRIBUTING.md and docs/maintenance.md. -->

## Why

What problem or maintenance need does this address?

## What changed

Describe the implementation at the level a future maintainer will care about.

## Ownership / scope

- [ ] Shared Ryoku desktop (`ryoku/`)
- [ ] NixOS packaging or module layer (`nix/`)
- [ ] Installer / materialization
- [ ] Documentation / tooling only
- [ ] Upstream Ryoku is also affected

If upstream is also affected, link the upstream issue/PR or explain why this
change remains NixOS-only.

## Verification

Commands/checks run:

```text
# paste the relevant commands, not the entire terminal session
```

Runtime verification (when applicable):

- NixOS version/channel:
- Ryoku channel/version:
- Compositor:
- Hardware/context:
- Behavior exercised:

## User-visible result

<!-- Leave blank for internal-only changes. -->

`Note: New|Fixed|Removed: ...`

## Checklist

- [ ] The diff is one logical change without unrelated cleanup.
- [ ] I can explain why each changed file belongs in its current ownership layer.
- [ ] Relevant focused tests/builds pass.
- [ ] Runtime-sensitive behavior was tested on a running system when applicable.
- [ ] Documentation changed if the public behavior or maintenance contract changed.
