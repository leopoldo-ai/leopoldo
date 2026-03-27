---
name: imprint
description: Adaptive learning engine. Observes corrections, preferences, and patterns. Dual mode: local (file-based) or cloud (API sync). Learns how the user works and adapts outputs over time. Use with /imprint commands.
---

# Imprint — Adaptive Learning Engine

Imprint makes every Leopoldo plugin learn how the user works. It observes corrections, preferences, and patterns. It builds a profile over time. It applies calibrations to future outputs so the system adapts without being told twice.

Imprint works in two modes: **local** (file-based, default, no account needed) and **cloud** (API sync, requires client_id). The mode can be switched at any time.

---

## Architecture: Code vs Data Separation

```
.claude/skills/imprint/SKILL.md     CODE — managed by Leopoldo updates, never touch
.leopoldo/imprint/                  DATA — user-owned, never touched by updates
  config.json
  profile.json
  observations.jsonl
  observations.processed.jsonl
```

This separation means:
- Leopoldo can update the engine skill (bug fixes, new logic) without touching any learned data
- The user's profile survives installs, reinstalls, and version upgrades
- Users can inspect, edit, back up, or delete their own data at any time

---

## Modes

| Mode | Storage | Requires | Default |
|------|---------|----------|---------|
| **local** | `.leopoldo/imprint/` on disk | Nothing | Yes |
| **cloud** | API sync to Leopoldo backend | client_id | No |

In **local** mode, all data stays on the user's machine. Processing happens in-context during the session. No network calls.

In **cloud** mode, the profile is synced to the backend on session end. The backend merges observations server-side. On session start, the latest calibrations are pulled down and cached locally.

Switch modes with `/imprint switch local` or `/imprint switch cloud`.

---

## Config

File: `.leopoldo/imprint/config.json`

```json
{
  "enabled": true,
  "mode": "local",
  "first_run_shown": false,
  "cloud": {
    "endpoint": "https://leopoldo-api-production.up.railway.app",
    "client_id": null
  },
  "profile_max_words": 500,
  "process_every_n_observations": 10
}
```

| Field | Description |
|-------|-------------|
| `enabled` | Master switch. If false, Imprint is fully dormant. |
| `mode` | `"local"` or `"cloud"` |
| `first_run_shown` | True after the opt-in prompt has been shown once |
| `cloud.endpoint` | Backend URL for cloud mode |
| `cloud.client_id` | Client identifier for cloud sync. Null until set. |
| `profile_max_words` | Cap on profile.json word count. Keeps context injection lean. |
| `process_every_n_observations` | How many raw observations before a processing pass runs |

---

## Local Storage

All files live under `.leopoldo/imprint/`. This directory is user-owned and never modified by updates.

| File | Purpose |
|------|---------|
| `config.json` | Settings and mode config (see above) |
| `profile.json` | Current calibrations. Injected into context every session. |
| `observations.jsonl` | Raw observations, append-only. One JSON object per line. |
| `observations.processed.jsonl` | Archive of observations already processed into the profile. |

If `.leopoldo/imprint/` does not exist, Imprint creates it on first activation. If `profile.json` is missing or empty, Imprint treats it as `{}` (no calibrations yet).

---

## Data Collection

### What Imprint observes

| Signal | Source | Example |
|--------|--------|---------|
| **Corrections** | Orchestrator Step 0 (correction detection) | "Wrong format", "redo with tables" |
| **Preferences** | Explicit user statements | "I always want executive summary first" |
| **Terminology** | Domain-specific terms the user uses or corrects | "We say 'investment thesis', not 'investment case'" |
| **Detail level** | How much detail the user requests or rejects | "Too verbose, be more concise" |
| **Output format** | Format patterns from accepted and rejected outputs | User consistently accepts bullet-point formats |
| **Language** | Working language preference | Italian, English, mixed |

### What Imprint does NOT collect

- File contents or proprietary data
- Full conversation transcripts
- Client names, deal names, or financial figures
- Anything the user marks as confidential
- Any data from skills or agents that do not trigger an observation event

---

## Observation Format

Observations are appended to `observations.jsonl` as newline-delimited JSON. One object per line.

```jsonl
{"ts":"2026-03-26T10:15:00Z","type":"correction","signal":"User asked to redo with tables instead of prose","skill":"reporting-output","context":"Quarterly board report"}
{"ts":"2026-03-26T10:22:00Z","type":"preference","signal":"Always start with executive summary","skill":null,"context":"General preference stated explicitly"}
{"ts":"2026-03-26T11:05:00Z","type":"terminology","signal":"Corrected 'investment case' to 'investment thesis'","skill":"due-diligence-flow","context":"Deal memo"}
{"ts":"2026-03-26T11:30:00Z","type":"pattern","signal":"User accepted concise format with 3-line summaries","skill":"consulting","context":"Strategy brief"}
{"ts":"2026-03-26T14:00:00Z","type":"format","signal":"Requested sensitivity table after every DCF","skill":"due-diligence-flow","context":"Financial model output"}
```

| Field | Values | Description |
|-------|--------|-------------|
| `ts` | ISO 8601 | Timestamp of the observation |
| `type` | `correction`, `preference`, `terminology`, `pattern`, `format` | Nature of the signal |
| `signal` | string | What was observed, in plain language. No transcripts. |
| `skill` | skill name or null | Which skill produced the output being corrected or accepted |
| `context` | string | Brief task description. No confidential content. |

---

## Profile Format

File: `.leopoldo/imprint/profile.json`

```json
{
  "version": "2.0.0",
  "updated_at": "2026-03-26T14:00:00Z",
  "observation_count": 47,
  "calibrations": {
    "output_format": "Always start with executive summary. Use tables over prose for structured data.",
    "detail_level": "concise",
    "terminology": {
      "investment_case": "investment thesis",
      "dd": "due diligence process"
    },
    "language": "english",
    "style_notes": "Prefers McKinsey-style frameworks. Always include 'so what' at the end of each section.",
    "domain_preferences": {
      "finance": "DCF with WACC, not APV. Always show sensitivity table after financial model.",
      "consulting": "Start with hypothesis, not data. Top-down structure."
    }
  }
}
```

An empty profile (no observations yet) is stored as `{}`. Imprint never injects an empty profile into context.

| Field | Description |
|-------|-------------|
| `version` | Schema version |
| `updated_at` | Last time the profile was processed and written |
| `observation_count` | Total raw observations processed so far |
| `calibrations.output_format` | Formatting rules (prose, tables, structure, ordering) |
| `calibrations.detail_level` | `concise`, `standard`, or `detailed` |
| `calibrations.terminology` | Key-value map of preferred term substitutions |
| `calibrations.language` | Working language |
| `calibrations.style_notes` | Style patterns and recurring preferences |
| `calibrations.domain_preferences` | Per-domain rules, merged across all observations |

---

## Flows

### Session Start

The SessionStart hook (`session-start.sh`) handles Imprint deterministically:

```
1. Hook reads .leopoldo/imprint/config.json
   → If missing or enabled = false: skip Imprint entirely.

2. Hook reads profile.json and injects FULL calibrations JSON via additionalContext
   → Not flattened. The complete calibrations object is injected so Claude
     can parse structured preferences (terminology maps, domain rules, etc.)

3. Hook checks observations.jsonl for unprocessed observations from previous sessions
   → If count > 0: instructs Claude to silently process them BEFORE handling
     the user's request. This is the PRIMARY processing trigger.
   → Processing is silent: the user sees no output about it.

4. Claude (in-context) handles first-run check:
   → If first_run_shown = false: show opt-in prompt once. Set first_run_shown = true.

5. Mode branch:
   LOCAL: done. Profile already loaded by hook.
   CLOUD: call GET {endpoint}/api/imprint/profile?client_id={client_id}
     → On success: merge with local profile (cloud wins on conflicts). Cache locally.
     → On failure: use local cache. Log warning.
```

**Why session start is the primary trigger:** The Stop hook fires only when Claude
explicitly finishes. If the user closes the terminal or the session times out,
Stop never fires and observations are never processed. By processing at session
start, we guarantee observations are always eventually synthesized — on the next
session, deterministically.

### Correction Detection

Fires when the orchestrator Step 0 detects a correction signal.

```
1. Extract signal: what the user corrected, which skill, what the task was
2. Sanitize: remove any names, figures, confidential identifiers
3. Append to observations.jsonl:
   {"ts":"...","type":"correction","signal":"...","skill":"...","context":"..."}
4. Check count: if new count >= process_every_n_observations → run Profile Processing
```

### Explicit Preference

Fires when the user states a clear preference or directive (e.g., "always do X", "never use Y", "I prefer Z").

```
1. Extract signal from the user's statement
2. Determine type: preference, terminology, or format
3. Sanitize
4. Append to observations.jsonl
5. Check count: if due → run Profile Processing
```

### Profile Processing

**Primary trigger:** SessionStart hook detects unprocessed observations from previous sessions and instructs Claude to process them silently before handling the user's request. This is deterministic: the hook always fires.

**Manual trigger:** User runs `/imprint process`.

```
1. Read all unprocessed lines from observations.jsonl
2. Read current profile.json (or {} if missing)
3. Apply Processing Template (see below) to synthesize updated calibrations
4. Write updated profile.json
5. Append processed observations to observations.processed.jsonl
6. Clear observations.jsonl (write empty file)
7. If cloud mode: schedule sync on session end
```

**Important:** Processing must be silent. No output to the user. The user should
only notice that outputs become more calibrated over time.

---

## Processing Template

When synthesizing observations into the profile, Claude follows these rules exactly:

**Input:** current `profile.json` calibrations + N new raw observations from `observations.jsonl`

**Rules:**

1. **Word cap.** The entire `calibrations` object must not exceed `profile_max_words` words (default 500). If over, compress style_notes and domain_preferences first. Never truncate terminology or output_format.

2. **Preserve existing calibrations.** Do not discard existing calibrations unless a new observation directly contradicts them. Contradiction requires at least 2 consistent signals, not a single instance.

3. **Recency priority.** More recent observations take priority over older ones when there is a conflict. Use the `ts` field to determine recency.

4. **Maintain schema.** Always output valid JSON matching the profile format. Do not add new top-level fields. Do not remove `version`, `updated_at`, `observation_count`.

5. **Be specific.** Prefer concrete rules ("always start with executive summary") over vague summaries ("user likes structure"). Specificity makes calibrations actionable.

6. **Terminology is additive.** New terminology corrections are merged into the existing map, not replaced. Never remove an existing term unless a later observation contradicts it.

7. **Resolve conflicts by recency.** If two observations contradict each other, keep the most recent. If the conflict is ambiguous, keep both and note in style_notes.

8. **domain_preferences: merge, don't replace.** New domain observations are merged into the existing domain entry. If a domain entry does not exist yet, create it.

9. **Update metadata.** Always update `updated_at` to the current timestamp. Increment `observation_count` by the number of newly processed observations.

10. **Output only the updated profile JSON.** No explanation, no commentary. Just the file.

---

## Cloud Mode Sync

Used only when `mode = "cloud"` and `cloud.client_id` is set.

### Session Start (cloud)

```
GET {endpoint}/api/imprint/profile?client_id={client_id}

Response: { calibrations: {...}, updated_at: "...", observation_count: N }

→ Merge with local profile (cloud takes priority on conflicts)
→ Cache to .leopoldo/imprint/profile.json
→ Inject calibrations into orchestrator context
```

### Session End (cloud)

```
POST {endpoint}/api/imprint/sync

Body: {
  "client_id": "...",
  "observations": [ ...unprocessed observations from observations.jsonl... ],
  "profile": { ...current local profile... }
}

Response: { calibrations: {...}, updated_at: "...", observation_count: N }

→ Write response to profile.json
→ Move synced observations to observations.processed.jsonl
```

If the API call fails, observations remain in `observations.jsonl` and will be retried on next session end.

---

## Commands

### `/imprint status`

Show current Imprint state.

Output includes:
- Enabled: yes / no
- Mode: local / cloud
- Profile: calibrations summary (output_format, detail_level, language, style count, domain count)
- Observations: N unprocessed, M total processed
- Last updated: timestamp from profile.json
- Cloud: connected / not configured (cloud mode only)

### `/imprint process`

Force a processing pass immediately, regardless of observation count.

Available in local mode only. In cloud mode, processing is server-side.

Steps:
1. Read all unprocessed observations from `observations.jsonl`
2. Apply Processing Template
3. Write updated `profile.json`
4. Move observations to `observations.processed.jsonl`
5. Confirm: "Profile updated. N observations processed."

### `/imprint reset`

Clear all Imprint data.

Steps:
1. Ask for confirmation: "This will delete your profile and all observations. This cannot be undone. Confirm?"
2. On confirmation:
   - Delete `profile.json`
   - Delete `observations.jsonl`
   - Delete `observations.processed.jsonl`
   - Reset `config.json` to defaults (keep mode and client_id)
   - If cloud mode: call DELETE `{endpoint}/api/imprint/profile?client_id={client_id}`
3. Confirm: "Imprint reset. All calibrations and observations cleared."

### `/imprint switch local|cloud`

Switch between modes.

`/imprint switch local`:
- Set `config.json` mode to `"local"`
- Confirm: "Imprint is now in local mode. All data stays on your machine."

`/imprint switch cloud`:
- If `cloud.client_id` is null: prompt for client_id before switching
- Set `config.json` mode to `"cloud"`
- Trigger a cloud sync immediately (push local profile to backend)
- Confirm: "Imprint is now in cloud mode. Profile will sync at session end."

---

## Privacy

- **Opt-in only.** Imprint does nothing until the user explicitly enables it.
- **Local by default.** No network calls unless the user switches to cloud mode.
- **No data sharing.** Imprint data is never shared, sold, or used to train models.
- **User controls everything.** Inspect, edit, export, or delete at any time. Files are plain JSON/JSONL.
- **Code/data separation.** Updates to the skill never touch `.leopoldo/imprint/`. Your profile is yours.
- **Minimal signals.** Only what the user says or corrects. Never file contents, transcripts, or client data.

---

*Version 2.0.0 — Engine skill — Included in every Leopoldo plugin*

*Dependencies: orchestrator (correction detection, context injection), leopoldo-manager (first-run), update-checker (session start hook)*
