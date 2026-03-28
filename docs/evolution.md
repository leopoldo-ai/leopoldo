# The Evolution Loop

Most tools degrade. Models update, usage patterns shift, new APIs emerge, and the system slowly falls out of sync. Leopoldo is designed to do the opposite: improve automatically, with user approval before anything changes.

This is the evolution loop.

---

## 1. The correction loop (real-time)

Every time a user corrects an output, a postmortem fires before the fix is applied.

```
User flags an error
  → correction-detector.sh hook detects signal (keyword match, IT + EN)
  → Postmortem gate set in gates.json (mechanically enforced)
  → gate-enforcer.sh BLOCKS Claude from responding until postmortem runs
  → Postmortem: root cause analysis (Detect → Analyze → Document)
  → Root cause logged in LESSONS_LEARNED.md and session journal
  → Gate auto-clears, fix proceeds
  → Failure feeds the next evolution cycle
```

This is not just error recovery. It is a data collection system. Every correction becomes a signal that feeds the weekly cycle. The enforcement is mechanical (hooks, not prompts): Claude cannot skip the postmortem even if it "wants" to.

---

## 2. The weekly evolution cycle

Every Thursday, the evolution agent wakes up and runs a three-part cycle using parallel subagents.

### Subagent 1: Internal retrospective

Reviews all postmortems, friction points, and state drift from the past seven days. Asks: where did the system slow down? Where did outputs miss expectations? Which workflows had the most corrections?

### Subagent 2: External radar

Scans the GitHub ecosystem feed and monitors the Anthropic SDK for changes. Asks: are there new patterns we should adopt? Did Claude's behavior shift in ways that affect our workflows? Are there new tools or APIs worth integrating?

### Subagent 3: Synthesis

Combines findings from both subagents into a set of proposed patches. Each patch is concrete and scoped: a specific capability to update, a workflow step to add, a gate threshold to adjust.

---

## 3. How patches get applied

The cycle produces a list of proposals. Nothing is applied automatically.

| Step | What happens |
|------|-------------|
| Proposals generated | Evolution agent outputs a numbered list with rationale |
| User reviews | You approve, reject, or defer each one |
| Approved patches queued | Added to `.state/state.json` pending tasks |
| Patches applied | System updates the relevant capabilities |
| Cycle logged | Full report saved to `.state/evolution/` |

---

## 4. A real example

In cycle 2, the evolution agent found 6 friction points across three workflows: two in the due diligence flow, two in report output formatting, and two in correction handling. It proposed 5 patches. All 5 were reviewed and applied. The correction rate on those workflows dropped by roughly half in the following week.

---

## 5. Why this matters

Traditional tools have a fixed surface. They are authored once and then maintained reactively, if at all. Leopoldo's architecture treats the system itself as a living artifact.

| Traditional tool | Leopoldo |
|-----------------|---------|
| Fixed at authoring time | Weekly improvement cycle |
| Corrections are one-off fixes | Corrections feed the evolution database |
| Model updates break things silently | External radar catches model/API drift |
| Users accumulate workarounds | Workarounds get formalized as patches |

The system improves automatically. You stay in control.
