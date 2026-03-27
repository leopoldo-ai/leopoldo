---
name: update-checker
version: 6.0.0
description: Backend-aware update system for Leopoldo plugins. Checks for updates ONLY when user runs /leopoldo update. Uses Leopoldo backend API with client API key. Integrity check (offline) runs every session. Never connects automatically.
skillos:
  layer: core
  category: meta
  pack: null
  requires:
    hard: []
    soft: ["leopoldo-manager"]
  provides: ["plugin-update", "integrity-check"]
  triggers: ["/leopoldo update", "/update"]
  config: {}
---

# Leopoldo Update Checker v6 — Backend-Aware

Explicit-only update system. NEVER connects automatically. Uses `leopoldo-client.json` for API key and backend URL. The only thing that runs on session start is an offline integrity check (no network, no API calls).

## Trigger

- **Manual only:** `/leopoldo update` or `/update`
- NOT on session start. NOT automatic. NOT silent.
- Integrity check (offline) still runs every session start — no network involved.

## Phase 1: Read state

1. **Detect format** by checking directory structure:
   - `.claude/skills/` exists → `claude-code`, manifest at `.claude/skills/.leopoldo-manifest.json`
   - `.claude-plugin/` exists → `cowork`, manifest at `.claude-plugin/skills/.leopoldo-manifest.json`

2. **Read `leopoldo-client.json`** — extract `api_key`, `api_url`, `client_id`.

3. **Legacy format check:** If `github_token` is found instead of `api_key`, show migration message and stop:

   > "This package uses an older update format. Contact hello@leopoldo.ai for an upgraded package."

4. **Read manifest** (`.leopoldo-manifest.json`) for installed plugin versions and skill hashes.

## Phase 2: Validate license

1. `GET {api_url}/api/licenses/validate` with header `X-Api-Key: {api_key}`

2. **If expired:** show message and STOP:

   > "License expired on {date}. Updates paused. Contact hello@leopoldo.ai to renew."

3. **If network error:** show message and STOP:

   > "Could not reach update server. Check your connection."

4. **If valid:** proceed to Phase 3.

## Phase 3: Check for updates

1. `GET {api_url}/api/updates/check` with header `X-Api-Key: {api_key}`

2. **If no updates available:** show version list and STOP:

   ```
   All plugins up to date.
     Investment Core v1.0.0
     Deal Engine v1.0.0
     124 skills managed, 3 user skills preserved
   ```

3. **If updates available:** show list with changelogs, ask user to confirm before proceeding.

## Phase 4: Download and install (manifest-aware)

1. **Create snapshot** before applying:
   - Copy current managed skill files to `.leopoldo-backup/snapshots/v{current}/`
   - Keep max 3 snapshots (delete oldest if needed)

2. **For each plugin to update:** `GET {api_url}/api/updates/download/{slug}` with header `X-Api-Key: {api_key}`

3. **Apply with manifest rules:**

   **A) Managed + hash matches manifest (user hasn't modified):**
   → Overwrite with new version, update hash in manifest. Count as "updated".

   **B) Managed + hash does NOT match (user modified):**
   → Do NOT overwrite. Mark as `"managed-modified"` in manifest. Count as "skipped (local changes)".

   **C) New skill (in update but not in manifest):**
   → Install, add to manifest as managed.

   **D) Skill in manifest but NOT in update (removed upstream):**
   → Keep it. Never auto-delete a skill.

4. **Update manifest:** new plugin versions, new skill hashes, new skills added, modified skills flagged.

5. **Regenerate CLAUDE.md Leopoldo section:**
   - Find `<!-- leopoldo:start -->` and `<!-- leopoldo:end -->`
   - Replace content between markers with updated info
   - If markers don't exist, append section at end of file

6. **Show brief summary:**

   ```
   Leopoldo updated: Investment Core v1.0.0 → v1.1.0
     45 updated, 2 skipped (local changes), 1 new
   ```

   If modified skills exist:
   ```
   2 skills have local changes (updates skipped):
     dd-screening, risk-framework
   Use /leopoldo update --force to override.
   ```

## Phase 5: Integrity check (offline, every session)

Runs on every session start. ZERO network calls. ZERO API requests.

1. Read manifest.
2. For each managed skill, verify the file exists on disk.
3. **Missing files found:** warn once: "N Leopoldo skills missing. Run /leopoldo repair."
4. **All healthy:** zero output.

## Soft Expiry Behavior

- Plugin works normally when expired (100% offline functionality preserved).
- `/leopoldo update` shows expiry message and stops.
- One-time reminder per session: "License expired. Updates paused. Contact hello@leopoldo.ai to renew."
- Check: read `leopoldo-client.json` → `expires` field. Compare with current date. If expired AND not already reminded this session, show reminder.

## Error Handling

| Error | Action |
|-------|--------|
| No network / timeout | "Could not reach update server. Check your connection." |
| 401 Unauthorized | "Invalid API key. Contact hello@leopoldo.ai." |
| 403 License revoked | "License revoked. Contact hello@leopoldo.ai." |
| 429 Rate limited | "Too many downloads today. Try again tomorrow." |
| 404 No version | Skip that plugin. |
| Old format (github_token) | "This package uses an older update format. Contact hello@leopoldo.ai for an upgraded package." |

## Rules

- NEVER check for updates on session start (only integrity check is automatic and offline)
- NEVER connect to any server without explicit user command
- Only data sent to the server: `api_key` in request header. No file contents, no Imprint data, no telemetry.
- Manifest is source of truth for all install state
- Never overwrite modified skills unless `--force` is passed
- Never delete skills automatically, even if removed upstream
- Always create a snapshot before applying any update
- Idempotent: running twice with same state produces same result

---

**Version:** 6.0.0 (backend API, explicit-only, offline integrity check)
**Type:** Engine skill (distributed in every plugin)
**Dependencies:** Read/Write tools, WebFetch (for backend API calls), Bash (for hash computation)
