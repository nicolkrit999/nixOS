---
name: spec-contract-module-list-drift
description: "option does not exist" from the spec-contract test means its hand-maintained module list drifted, NOT an untracked file - overrides the default error taxonomy for this one test
metadata:
  type: reference
---

`templates/tests/nixos/test-spec-contract/01-scenario-spec-contract.nix` builds a
**synthetic host from a hand-written `nixosPaths` list**, not from a real host config.
It is not denix auto-discovery.

So an error like `The option 'specialisation.<spec>.configuration.myconfig.programs.X'
does not exist` from this test means: a specialisation under
`users/krit/nixos/specializations/` gained a new `myconfig.programs.X` override, and
nobody added `modules/.../X.nix` to `nixosPaths`.

**Why:** CLAUDE.md's error taxonomy says "option does not exist" is usually an untracked
file (flakes ignore untracked). That rule does **not** apply here - this scenario's
module set is explicit and drifts silently whenever a specialisation grows a new override.
Checking `git status` first wastes a cycle.

**How to apply:** read the failing option path, find which module declares it
(`grep -rn 'name = "programs.X"' modules/`), and add that path to `nixosPaths` with a
comment naming the spec that needs it. Then re-run
`bash templates/tests/nixos/test-spec-contract/check-nixos-spec-contract.sh`.
Note the same drift risk exists for any specialisation option, not just waybar.
Related: [[fetchurl-ssl-line-is-noise]].
