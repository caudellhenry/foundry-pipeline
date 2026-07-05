---
description: Show the full diff between local install and canonical foundry-pipeline v2.0.0
argument-hint: ""
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:patch-diff`

Show the full diff between local install and canonical.

## Behaviour

```bash
# If git checkout:
git -C "$INSTALL_DIR" diff v2.0.0..HEAD

# If not git checkout:
diff -ruN "$INSTALL_DIR" <(curl -sL https://github.com/caudellhenry/foundry-pipeline/archive/refs/tags/v2.0.0.tar.gz | tar -tz)
```

The output is shown to the user verbatim. No edits are made.

## Exit codes

- 0 — diff printed
- 1 — local equals canonical (nothing to diff)