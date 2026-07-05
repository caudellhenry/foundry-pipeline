---
name: diagnose
description: Disciplined diagnosis loop for hard bugs and performance regressions — reproduce, minimise, hypothesise, instrument, fix, regression-test. Use when a failure's cause is not obvious within one look.
---
foundry_version: 2.0.2

# diagnose — the bug loop

Agents misdiagnose root causes and chase rabbit holes when they skip discipline. Never fix what you have not reproduced.

1. **Reproduce.** A deterministic, scripted reproduction — ideally a failing test. No repro, no fix.
2. **Minimise.** Shrink the repro until every remaining element is necessary. The minimal case usually names the culprit.
3. **Hypothesise.** State the suspected cause in one sentence BEFORE touching code. If you cannot, gather more evidence.
4. **Instrument.** Add targeted logging/assertions to confirm or kill the hypothesis. Judge on evidence, not plausibility. Wrong → new hypothesis; after 3 dead hypotheses, summarise the evidence and ask the human.
5. **Fix** the root cause, not the symptom, via the `tdd` skill (the minimal repro becomes the regression test).
6. **Regress.** Full suite green; instrumentation removed; one-paragraph root-cause note in the ticket/PR.
