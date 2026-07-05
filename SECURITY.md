# Security Policy

> Single source of truth: `caudellhenry/foundry-pipeline`.

---

## Supported versions

| Version | Supported |
|---|---|
| 2.0.0 (current) | ✅ |
| 1.3.x (Zcode plugin — superseded) | ❌ |
| 0.1.0 (GitHub v0.1.0 — superseded) | ❌ |

---

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Email: **security@caudellhenry.dev** (or whatever you have in your GitHub profile).

Include:
- Description of the vulnerability
- Reproduction steps (or a PoC)
- Affected version (e.g., `v2.0.0`)
- Your assessment of severity (low / medium / high / critical)

You'll get an acknowledgement within 48 hours and a status update within 7 days.

---

## What foundry-pipeline does and doesn't do (security scope)

### Does:
- Runs **only** the scripts you explicitly invoke (`install.sh`, `foundry-self-update.sh`, etc.).
- Reads/writes files in your project (`.foundry/`, `.mcp.json`).
- Optionally talks to GitHub / Linear via:
  - **MCP servers** (declarative, no creds in our hands)
  - **`gh` CLI** (uses your existing auth)
  - **Token env vars** (`$GITHUB_TOKEN`, `$LINEAR_API_KEY`) — Foundry never logs or stores these.

### Doesn't:
- Run untrusted code (all shipped scripts are versioned + signed by tag in our repo).
- Phone home (only outbound calls are: GitHub API for patch-detection + tracker creation, Linear API for tracker creation).
- Store credentials (no credential files; relies on your existing auth).

---

## Built-in security features

- **Patch detection** — if you edit installed files, you get a prompt at every SessionStart to push the patch upstream. This catches tampering.
- **Iteration cap** — `state.md security.iteration_cap` bounds agent loops (default 50; configurable per project).
- **Pre-tool-use guardrails** — blocks `rm -rf /`, `sudo`, writes outside project root (in claude-code + zcode packages).
- **Force-push protection** — `protect-branches.sh` in claude-code + zcode blocks `git push --force`, `git push origin main`, etc.
- **Iteration-chain check** — `stop-hook.sh` enforces arXiv 2506.11022 bound (r≈0.64) on iteration depth.
- **Secret scanning** — GitHub repo has secret scanning enabled + push protection enabled.
- **Dependabot** — disabled by default; can be enabled per project.

---

## Audit checklist for production use

Before adopting foundry-pipeline in a production / enterprise context, audit:

- [ ] Review the `scripts/foundry-self-update.sh` output for divergence every SessionStart.
- [ ] Set `state.md security.iteration_cap` to a value appropriate for your domain.
- [ ] Decide on tracker backend (local is safest; GitHub/Linear require MCP or env tokens).
- [ ] Review the `pre-tool-use.sh` blocklist for your shell habits (you can extend it).
- [ ] Decide whether to allow `/foundry:loop-on` (AFK mode — defaults off).
- [ ] Read [`docs/PATCH_PUSH_WORKFLOW.md`](docs/PATCH_PUSH_WORKFLOW.md) to understand what happens when you edit installed files.

---

## Security updates

Security fixes land in patch releases (`v2.0.1`, `v2.0.2`, …). Subscribe to GitHub releases to get notified.

---

## Acknowledgements

Thanks to the security researchers and contributors who report vulnerabilities responsibly.