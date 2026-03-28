# Orchestrator — Lessons Learned

## 2026-03-28 | Railway env var escaping + postmortem gate skip

**Severity:** High
**Type:** user-correction
**Context:** Setting bcrypt hash as Railway env var for admin login

### Root Cause
1. Bcrypt hashes contain `$` characters. Railway CLI interprets `$` as shell variable expansion, truncating the value. Took 6+ attempts instead of pivoting after 2.
2. On user correction signal ("stai sclerando"), orchestrator acknowledged but did NOT trigger the mandatory postmortem gate (Step 0 violation).

### Lessons
- **ALWAYS** test env var values with special characters (`$`, `!`, `#`) by reading back immediately after setting. If truncated, pivot to dashboard or API.
- **NEVER** retry the same failing approach more than twice. After 2 failures, stop and change strategy (different tool, different encoding, different channel).
- **ALWAYS** trigger postmortem on correction signals before ANY other response. The gate is non-negotiable. "Acknowledging the feedback" is not the same as running the postmortem.
- **ALWAYS** for bcrypt hashes on Railway, use the web dashboard or wrap in single quotes with explicit verification.

### Prevention
- Add a mental checklist for env var operations: set → verify → test endpoint
- Correction detection must be reflexive, not reasoned about
