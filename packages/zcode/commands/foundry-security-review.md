---
description: Security audit of a diff, a new tool/MCP server, or the agent setup itself
argument-hint: "<diff|tool-name|setup>"
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:security-review`

Backed by the `security-review` skill (`packages/core/skills/security-review/SKILL.md`).

## Two modes

### (a) Diff / release

- Static analysis (semgrep, CodeQL if available)
- Classic vulnerability check (OWASP top 10, secrets in code, SQLi, XSS, SSRF, path traversal)
- Iteration audit (arXiv 2506.11022 — bounded iteration chains, r≈0.64)
- Complexity audit (cyclomatic / cognitive complexity per function)

### (b) New tool / MCP server

- Lethal-trifecta audit (untrusted input + sensitive data + external communication)
- Version pinning (no floating majors)
- Supply-chain check (registry trust, author verification)
- Credential scoping (least privilege)
- Bounded responses (size limits, schema validation)

## When to use

- Before any release
- Before adopting any new tool or MCP server

## Exit codes

- 0 — clean
- 1 — high-severity finding (block release)
- 2 — medium-severity finding (fix before next release)