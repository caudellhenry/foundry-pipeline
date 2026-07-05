---
pipeline: dev
version: 1
created: 2026-07-03
updated: 2026-07-03
current_phase: idea
auto_loop: false
last_session_id: ""
test:
  runner: auto                # auto-detected on /foundry-init from package.json/pyproject.toml/go.mod/Cargo.toml
  cmd: ""                     # full test command (filled by foundry-auto-detect-test.sh or manually)
  per_story_cmd_template: ""  # e.g. "pnpm test -- --testPathPattern={path}"
  timeout: 300                # seconds
  coverage_cmd: ""            # optional
  coverage_threshold: 0       # %, 0 = no gate; auto-baseline still enforces no regression
  coverage_baseline: null     # auto-measured on first run, enforced ≥ baseline - 2
  lint_cmd: ""                # optional
  typecheck_cmd: ""           # optional
  skip_tests: false           # explicit opt-out (use only when no test suite exists yet)
  cache_by_commit: true       # cache last result per (ticket, commit)
models:
  writer: sonnet              # general-purpose profile model for ticket implementation (v1.0.0 alias for implementer)
  explorer: lite              # v1.0.0 — Explore profile model for read-only scout
  planner: lite               # v1.0.0 — Explore profile model for plan-mode (skip_plan: true for one-sentence diffs)
  implementer: sonnet        # v1.0.0 — general-purpose profile model for TDD ticket implementation
  committer: lite             # v1.0.0 — general-purpose profile model for mechanical commit + board update
  tester: lite                # v1.0.0 — Explore profile model for adversarial acceptance check
  reviewer: lite              # Explore profile model for per-ticket review
  cross_reviewer: lite        # Explore profile model for cross-ticket coherence review
  qa_planner: sonnet          # general-purpose profile model for QA round synthesis
foundry:
  iteration_chain:           # v1.0.0 — arXiv 2506.11022 security iteration-cap
    current_failure_id: null  # hash of "<ticket>:<test_name>" identifying the failing test
    count: 0                 # consecutive LLM-only failures on the same failure_id
    last_human_review_at: null  # ISO; reset count to 0 on human review
  security:
    trifecta_audit_due: false  # true when new tool/MCP surface added
    complexity_baseline: 0     # cyclomatic complexity of codebase at signoff
    complexity_threshold: 50   # block release when current > baseline * 1.5
signoff:
  user_signed_off: false
  signed_off_at: null
  signed_off_by: null
worktree:
  enabled: true                # v1.3.0 — per-ticket worktree isolation (FR-20260704-008)
  parent_dir: ".."             # relative to PROJECT_ROOT; default = sibling directory
  prefix: ""                   # optional; default = "<project_basename>-STORY-<ID>"
parallel:
  enabled: false               # v1.3.0 — parallel fan-out (FR-20260704-009)
  max_workers: 3               # max concurrent writer sub-agents per loop iteration
  strategy: serial-merge       # serial-merge | all-or-nothing
phases:
  idea:
    status: pending
    started: null
    completed: null
    artifacts:
      intent: .foundry/idea/intent.md
      risks: .foundry/idea/risks.md
  research:
    status: pending
    started: null
    completed: null
    artifact: .foundry/research/research.md
    expires: null
  prototype:
    status: pending
    started: null
    completed: null
    artifacts:
      notes: .foundry/prototype/notes.md
      paths: []
  prd:
    status: pending
    started: null
    completed: null
    artifact: .foundry/prd.md
  tdd:
    status: pending
    started: null
    completed: null
    specs_dir: .foundry/tdd/
  plan:
    status: pending
    started: null
    completed: null
    artifacts:
      features: .foundry/plan/features.md
      stories_dir: .foundry/plan/stories/
      board: .foundry/plan/board.md
  execute:
    status: pending
    started: null
    completed: null
    iterations: 0
    completed_tickets: []
    platform: none             # none | github | gitlab — gates the External-Review Convergence sub-loop
    prs: {}                   # ticket → PR/MR URL map, only populated when platform != none
    pr_state_dir: .foundry/pr-state/  # per-ticket PR state files
  qa:
    status: pending
    started: null
    completed: null
    rounds: 0
    verdict: null
board:
  file: .foundry/plan/board.md
  tickets: []
qa:
  plan: .foundry/qa/qa-plan.md
  evidence_dir: .foundry/qa/evidence/
  test_runs_dir: .foundry/qa/evidence/test-runs/
  review_dir: .foundry/qa/review/
  cycles: []
loop_state:
  phase5_active: false
  phase6_iteration: 0
  phase7_round: 0
---