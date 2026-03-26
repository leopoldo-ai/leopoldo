# Architecture | Leopoldo

Leopoldo is an expertise system for Claude. Not a prompt collection. Not a library of templates. A runtime that orchestrates domain expertise, enforces quality, detects and corrects errors, and evolves automatically over time.

The system is the product. Domain expertise is the content delivered through it.

---

## Overview

Leopoldo is built on three layers:

- **Engine.** The runtime: orchestrator, quality gates, correction loop, lifecycle manager, update checker, and Imprint (local learning). This is what makes Leopoldo a system rather than a collection of files.
- **Packs.** Domain expertise organized by vertical. Finance, consulting, legal, intelligence, dev, and the common foundation included in every plugin.
- **Studio.** The production toolchain. Capability authoring, testing, and validation. How capabilities are produced systematically rather than ad hoc.

---

## System Diagram

```
User Request
  -> Orchestrator (intent classification, routing)
    -> Workflow Agent (specialized agents per plugin)
      -> Capability execution
        -> Quality Gate (structure, completeness, actionability)
          -> Output to user

On correction:
  -> Postmortem (root cause analysis)
    -> Fix with awareness
      -> Logged for evolution

Weekly:
  -> Evolution Agent
    -> Internal retrospective (frictions, patches)
    -> External radar (ecosystem changes)
      -> Patch proposals -> User approval -> System improves
```

---

## Engine Layer

The engine is what separates Leopoldo from a folder of markdown files.

### Orchestrator

The main routing agent. Receives every user request, classifies intent, selects the appropriate workflow agent, and monitors execution. The orchestrator also enforces gates, detects correction signals, and manages session lifecycle.

### Quality Gates

Three gates block output when conditions are not met:

| Gate | Threshold | Triggers on |
|------|-----------|-------------|
| Phase Gate | 80% default, 100% for security/deploy | Missing capability coverage for a workflow phase |
| Doc Gate | 100% | Project documentation out of sync with completed work |
| Security Gate | 100%, no exceptions | Auth, API, data, or deployment changes |

Gates are blocking. Only the user can override with an explicit instruction.

### Correction Loop

When a user corrects an output:

1. The orchestrator detects the correction signal.
2. `skill-postmortem` runs before any re-work. Root cause is identified.
3. The fix is applied with awareness of what failed and why.
4. The failure is logged and queued for the next evolution cycle.

The system gets better from corrections rather than just repeating them differently.

### Lifecycle Manager

Handles the full plugin lifecycle for users installing Leopoldo into their projects:

- Install, add, update, repair, rollback, remove, uninstall
- Manifest-based tracking: distinguishes managed capabilities (auto-updated) from user-owned files (never touched)
- CLAUDE.md merge via non-destructive markers
- Snapshot creation before every update (max 3, auto-rotated)
- Integrity check on every session start

### Update Checker

Manifest-aware update feed:

- Reads the local manifest to know which capabilities are managed
- Checks GitHub Releases API for new versions (no auth required)
- Only updates managed capabilities with unchanged hashes
- User modifications are preserved (hash mismatch means skip, not overwrite)
- Legacy installs without a manifest are auto-migrated on first session

### Imprint

Local learning layer available in Leopoldo Full and as a standalone premium plugin.

- Observes output preferences, correction patterns, terminology, and style
- Builds a calibration profile stored locally (never synced without explicit opt-in)
- Applied at session start to adapt all capabilities to the user's working style
- Privacy-first: opt-in, encrypted at rest, never used for training

---

## Pack Layer

Domain expertise organized by vertical. Each pack contains capabilities specific to its domain. The common pack (essentials and design foundations) is included in every plugin.

| Pack | Domain | Included in |
|------|--------|-------------|
| common/essentials | Core methodology, output standards | Every plugin |
| common/design-foundations | Design system, visual language | Every plugin |
| dev/full-stack | Full-stack development | full-stack plugin |
| finance/investment-core | Investment analysis | investment-core plugin |
| finance/deal-engine | PE/VC and M&A | deal-engine plugin |
| finance/fund-suite | Fund management | fund-suite plugin |
| finance/advisory-desk | Investment banking | advisory-desk plugin |
| finance/markets-pro | Trading and portfolio | markets-pro plugin |
| consulting/senior-consultant | Strategic consulting | senior-consultant plugin |
| consulting/marketing | Brand, content, growth | marketing plugin |
| consulting/med-research | Clinical and biostatistics | medical-research plugin |
| intelligence/competitive-intelligence | Market positioning | competitive-intelligence plugin |
| legal/legal-suite | Compliance, contracts, regulatory | legal-suite plugin |

---

## Studio Layer

Studio is the production toolchain used to author, test, and validate capabilities before they enter the system. It includes:

- **Capability authoring tools.** Structured templates and authoring guides for creating new capabilities consistently.
- **Testing framework.** Local validation before capabilities are packaged for distribution.
- **Validation pipeline.** Checks that capabilities meet quality standards (trigger coverage, output format, example prompts) before they are added to a pack.

Studio tools are never distributed to users. They run in the development environment only.

---

## Agent System

The platform includes 4 public agents:

| Agent | Purpose |
|-------|---------|
| `orchestrator` | Routes requests, enforces quality gates, manages corrections |
| `system-claw` | Environment scanning, setup, diagnostics, health checks |
| `reporting-output` | Professional document generation (docx, pptx, xlsx) |
| `evolution-agent` | Weekly auto-improvement cycle |

Premium plugins add domain-specific agents:

| Plugin | Agents | Purpose |
|--------|--------|---------|
| Finance | 6 agents | Due diligence, deal execution, fund management, advisory, markets, wealth |
| Legal | 4 agents | Contract lifecycle, corporate counsel, dispute resolution, legal operations |
| Consulting | 3 agents | Strategic consulting, medical research, marketing |
| Competitive Intelligence | 3 agents | CI pipeline, people profiling, market monitoring |

---

## Quality Gates (Detail)

### Phase Gate

After each workflow phase, the orchestrator verifies that all relevant capabilities for that phase were invoked. Coverage below threshold blocks progression.

- Default threshold: 80%
- Security-related phases: 100%
- Deployment phases: 100%

Below threshold: phase is marked BLOCKED. The orchestrator surfaces what was missed before continuing.

### Doc Gate

Project documentation must reflect completed work. If a task produces a decision, architecture change, or significant output that should be documented and the relevant docs are not updated, the doc gate fires.

The gate blocks the next task until documentation is brought in sync.

### Security Gate

100% threshold. No exceptions. Applies to any change touching authentication, API design, data handling, or deployment configuration. The security gate cannot be overridden by the orchestrator. Only an explicit user instruction bypasses it.

---

## Evolution Cycle

The system improves itself on a weekly schedule (every Thursday, or manually triggered).

### Process

1. The orchestrator detects that evolution is due (7-day interval since last run).
2. Three parallel subagents are dispatched:
   - **Internal retrospective.** Reviews session journals for friction points, correction patterns, and capability gaps. Identifies what failed and why.
   - **External radar.** Monitors the GitHub ecosystem feed for relevant changes in tools, libraries, and methodologies used by the packs.
   - **Ecosystem scan.** Tracks Anthropic SDK updates, Claude capability changes, and platform shifts that may require capability updates.
3. Subagents produce findings. The evolution agent synthesizes a patch proposal report.
4. The report is presented to the user for review. No changes are applied without explicit approval.
5. Approved patches are queued in `.state/state.json` and applied in the next session.
6. The evolution run is logged with timestamp, findings, and approval status.

### What gets improved

- Capabilities with repeated correction patterns
- Gaps identified from workflow friction
- Outdated references to external tools or APIs
- New capability proposals based on observed user needs

---

## Data Flow

How a request moves through the system from start to finish:

```
1. User sends a request in Claude Code or Cowork

2. Session lifecycle (engine)
   - Session ID generated
   - Journal file opened (.state/journal/)
   - Imprint profile loaded (if available)
   - Update check run against manifest

3. Orchestrator (engine)
   - Intent classified
   - Domain identified
   - Workflow agent selected

4. Workflow agent (agents/)
   - Multi-step process initiated
   - Relevant capabilities loaded from the pack
   - Phase gate checked at each workflow phase

5. Capability execution (packs/)
   - Domain expertise applied
   - Output structured per output standards (exec summary, tables, actionable recommendations)

6. Quality gate (engine)
   - Structure verified
   - Completeness checked against phase threshold
   - Doc gate and security gate evaluated if applicable

7. Output delivered to user

8. On correction signal:
   - Postmortem runs (root cause, affected capability)
   - Fix applied with context
   - Failure logged to session journal for next evolution cycle

9. Session end
   - Journal closed with session.end event
   - Imprint observations flushed (if local learning active)
   - Checkpoint run if 3+ tasks completed
```

---

## File Structure

```
leopoldo/
  skills/             Capabilities (packs, engine, studio)
  agents/             Workflow agents (orchestrator + domain-specific agents per plugin)
  agents/studio/      Studio agents (evolution-agent, development only)
  web/                Next.js website (leopoldo.ai)
  api/                FastAPI + LangGraph backend
  distribution/       Plugin packaging and delivery pipeline
  brand/              Brand identity and assets
  docs/               Architecture, decisions, specs, guides
  tests/              Test suite
  .state/             System state (journals, snapshots, evolution history)
  .claude/            Claude Code config (symlinks to skills/ and agents/)
```

---

## Design Principles

1. **The system is the product.** Expertise without orchestration is a document. The value is in the runtime that routes, validates, corrects, and evolves.

2. **Corrections are data.** Every user correction is logged, analyzed, and fed into the evolution cycle. The system treats friction as signal.

3. **Gates are blocking by design.** Quality gates that can be silently bypassed are not quality gates. They block until resolved or explicitly overridden by the user.

4. **User files are never touched.** The lifecycle manager distinguishes managed capabilities from user-owned files. Manifest-based tracking ensures updates never overwrite user modifications.

5. **Evolution requires approval.** The evolution agent proposes. The user decides. No changes are applied automatically without explicit sign-off.
