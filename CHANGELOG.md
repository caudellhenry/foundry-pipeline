# Changelog

All notable changes to **foundry-pipeline** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] — 2026-07-05

### Added
- **Canonical monorepo** at `caudellhenry/foundry-pipeline` — single source of truth for v2.0.0+
- **Single `VERSION` file** drives every package's `package.json` + `plugin.json` via `scripts/foundry-version-sync.sh`
- **CI version-sync guard** — fails PR if any package version drifts from root `VERSION`
- **8 harness packages** under `packages/`: `core`, `claude-code`, `zcode`, `skills-sh`, `hermes`, `opencode`, `antigravity`, `mimocode`
- **Tracker adapter pattern** — local / GitHub / Linear at install time via `/foundry:init` wizard
- **Git-aware patch detection** — `foundry-self-update.sh` detects local divergence from canonical tag and offers `/foundry:patch-{check,diff,push,reset,skip}`
- **`foundry_version:` stamping** in every SKILL.md, script header, and agent frontmatter so any agent can `grep foundry_version` to verify its install
- **CI workflows**: `foundry-evals.yml`, `foundry-version-sync.yml`, `foundry-monorepo-build.yml`, `foundry-publish.yml`
- **Release-drafter** at `.github/release-drafter.yml`

### Changed
- **Breaking**: previous v0.1.0 (`caudellhenry/foundry`) and v1.3.0 (Zcode `Skills/foundry`) are now archived/superseded. Migration script `packages/core/scripts/foundry-migrate.sh` auto-detects old installs.

### Removed
- None (this is the initial canonical release).

[Unreleased]: https://github.com/caudellhenry/foundry-pipeline/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/caudellhenry/foundry-pipeline/releases/tag/v2.0.0