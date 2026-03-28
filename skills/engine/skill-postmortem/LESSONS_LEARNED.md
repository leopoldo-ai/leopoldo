# Skill Post-Mortem — Lessons Learned

## [2026-03-27] — Auto-improvement processes never executed

**Type:** wrong-output (systemic process drift)
**Severity:** Critical
**Fase workflow:** Orchestrator Step 0 (postmortem), Step 5 (checkpoint), Session Start (evolution)

### Cosa e' successo

The orchestrator defines 3 auto-improvement processes:
1. Post-mortem on every correction (Step 0)
2. Checkpoint every 3 tasks (Step 5)
3. Evolution cycle weekly (Session Start)

Audit of all journal files showed: 0 `postmortem.completed` events, 0 `checkpoint.completed` events. The processes existed in the spec but were never executed in practice.

### Root Cause

**Declarative vs mechanical enforcement.** The processes relied on the orchestrator's "self-discipline" to remember and execute them during task pressure. Every new session started without memory of the task counter. The correction-detector hook only suggested "consider running /postmortem" instead of forcing it. The checkpoint gate was soft (needs 2 warnings to block) with a threshold of 6 edits (too high).

### Fix applicato

4-file structural fix to make processes mechanically enforced:

1. **correction-detector.sh**: Now sets `postmortem.required = true` in gates.json and logs `correction.detected` event. Stronger additionalContext makes it an obligation, not a suggestion.
2. **gate-enforcer.sh**: New postmortem gate check (highest priority, hard enforcement). Blocks Claude's response if correction detected but no `postmortem.completed` in journal. Auto-clears when postmortem is logged.
3. **tool-logger.sh**: Increments `task_count_since_checkpoint` persistently in gates.json. Detects postmortem completion signals. Checks both `checkpoint.passed` and `checkpoint.completed` events.
4. **session-start.sh**: Initializes `postmortem` field in gates.json. Lowered checkpoint threshold from 6 to 3.

### Patch proposto alla skill

Applied directly to hook scripts (mechanical enforcement layer). Status: Applicato.

### Lezione

**NEVER** rely on orchestrator self-discipline for critical processes. **ALWAYS** enforce via persistent state (gates.json) + mechanical hooks (shell scripts that block). Advisory context ("consider doing X") is ignored under task pressure. Only hard gates (exit 2) guarantee execution.
