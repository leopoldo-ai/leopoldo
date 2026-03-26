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

- **Orchestrator**: routes tasks to the right workflow agent
- **Agents**: Specialized workflow agents for multi-step processes. The open-source platform includes system-claw, reporting-output, and the evolution agent. Premium plugins add domain-specific agents (6 for finance, 4 for legal, 3 for consulting, 3 for competitive intelligence).
- **Quality gates**: phase gates, doc gates, security gates. Blocking, not advisory.
- **Correction loop**: every user correction triggers a postmortem before the fix
- **Evolution cycle**: weekly automated improvement, user-approved before applied

## Installing

```bash
/leopoldo install [plugin-slug]
```

That's it. The system handles CLAUDE.md merge, conflict resolution, and manifest tracking automatically.

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
