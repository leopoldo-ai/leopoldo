# How Leopoldo Works

Leopoldo is an expertise system for Claude. Not a prompt library. Not a collection of templates. A system: orchestrator, agents, quality gates, correction loop, and auto-evolution, all working together so Claude produces expert-level, structured outputs on real professional tasks.

## What makes it different

| Dimension | Prompt libraries | Leopoldo |
|-----------|-----------------|---------|
| Output type | Chat responses | Structured deliverables (reports, models, briefs) |
| Quality control | None | Blocking gates at every workflow phase |
| Error handling | Manual re-prompt | Automatic postmortem, root cause logged |
| Improvement over time | Degrades as models shift | Auto-evolution cycle, weekly |
| Vertical depth | Generic | Domain packs: finance, legal, consulting |
| Installation | Copy-paste | One command |

## What you get

Every installation includes the full system:

- **Orchestrator**: routes tasks to the right workflow agent based on intent. Uses agent descriptions for implicit routing (no keyword tables).
- **Agents**: Specialized workflow agents for multi-step processes. The open-source platform includes system-claw, reporting-output, and dev-setup. Premium plugins add domain-specific agents (6 for finance, 4 for legal, 3 for consulting, 3 for competitive intelligence).
- **Hooks**: 6 lifecycle hooks that run mechanically (not prompt-based):
  - `session-start.sh`: initializes session state, loads Imprint profile
  - `correction-detector.sh`: detects user corrections, enforces postmortem before any fix
  - `gate-enforcer.sh`: blocks Claude from proceeding when quality gates are pending
  - `pre-edit-validator.sh`: protects system files from accidental modification
  - `tool-logger.sh`: tracks all tool usage, triggers checkpoint gates
  - `core.sh`: shared utilities for project root discovery and state management
- **Quality gates**: phase gates, doc gates, security gates. Blocking, not advisory.
- **Correction loop**: every user correction triggers a postmortem before the fix. Mechanically enforced by hooks.
- **Imprint**: adaptive learning layer. Observes corrections, builds a calibration profile, applies preferences at session start. You never repeat yourself.
- **system-claw**: scans your MCP servers, CLI tools, and hooks on session start. Routing adapts to your actual environment.
- **Evolution cycle**: weekly automated improvement, user-approved before applied

## What gets installed

```
.claude/
  skills/       Domain expertise
  agents/       Workflow agents (orchestrator + domain agents)
  settings.json Hooks, permissions, agent configuration
.leopoldo/
  hooks/        6 lifecycle hook scripts
  imprint/      Learning data (profile, observations)
.state/
  journal/      Session logs (append-only)
  state.json    System state (plugins, evolution, sessions)
CLAUDE.md       Project instructions (merged non-destructively)
GETTING_STARTED.md  Installation guide
```

## Installing

```bash
/leopoldo install [plugin-slug]
```

That's it. The system handles CLAUDE.md merge, hook wiring, conflict resolution, and manifest tracking automatically.

## Premium plugins

For deep vertical expertise, premium plugins are available on request:

| Plugin | Use cases |
|--------|-----------|
| Finance | Due diligence, deal execution, fund management, trading |
| Legal | Contract review, corporate law, disputes, IP, labour |
| Consulting | Engagement management, market sizing, marketing |
| Competitive Intelligence | Competitor analysis, market positioning |

## Support

- Email: hello@leopoldo.ai
- Services and team setup: leopoldo.ai/services
