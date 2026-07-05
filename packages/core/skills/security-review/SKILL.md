---
name: security-review
description: Security audit of a diff, a new tool/MCP server, or the agent setup itself — static analysis, lethal-trifecta exposure, iteration-chain and complexity checks. Use before release, and before adopting any new tool or MCP server.
disable-model-invocation: true
---
foundry_version: 2.0.2

# /security-review — trifecta, iteration, complexity

Prompt injection is a frontier, unsolved problem; agent-involved incidents are routine. Defence is layered, not clever.

## For a diff / release

1. Run available static analysis (semgrep/CodeQL/linters with security rules) on changed files; triage findings by reachability.
2. Check the classics by hand on the diff: injection (SQL/shell/HTML), authn/z on new endpoints, secrets in code or logs, unsafe deserialisation, path traversal.
3. **Iteration audit:** confirm no code path shipped with more than 3 consecutive LLM-only fix iterations since the last human review (`iteration_chain` history).
4. **Complexity audit:** flag files whose complexity grew sharply — complexity growth correlates with vulnerability introduction (r ≈ 0.64).
5. Verdict: pass / conditional (list) / block. Record in `gates.security_ok`. Blockers become tickets.

## For a new tool / MCP server

1. **Lethal-trifecta audit** — does the agent setup now combine: (a) untrusted content, (b) private data access, (c) external communication? If all three, require the user to break one leg (scoping, read-only tokens, no-network) before approval.
2. Server pinned by version; source reviewed (MCP has no built-in auth/integrity verification — treat servers as supply-chain dependencies).
3. Credentials live outside the agent context (gateway pattern); minimum-scope tokens.
4. Tool responses bounded (pagination/truncation within token budgets).
