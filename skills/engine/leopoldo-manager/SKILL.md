---
name: leopoldo-manager
version: 1.0.0
description: Plugin lifecycle manager for Leopoldo. Handles install, add, update, remove, repair, rollback, and uninstall. Manifest-based tracking ensures safe updates, deduplication across plugins, conflict resolution, and preservation of user customizations. Use with /leopoldo commands.
skillos:
  layer: core
  category: meta
  pack: null
  requires:
    hard: []
    soft: ["update-checker"]
  provides: ["plugin-management", "manifest", "skill-dedup"]
  triggers: []
  config: {}
---

# Leopoldo Manager — Plugin Lifecycle Management

Manages the full lifecycle of Leopoldo plugins in any project: install, add, update, remove, repair, rollback, and uninstall. Uses a manifest to track what is managed vs user-owned, enabling safe updates that never destroy user customizations.

## Commands

| Command | Purpose |
|---------|---------|
| `/leopoldo install [slug]` | First-time install of a plugin in the current project |
| `/leopoldo add [slug]` | Add another plugin (dedup shared skills) |
| `/leopoldo update` | Force update check now |
| `/leopoldo update --force` | Update including locally modified skills |
| `/leopoldo status` | Show installed plugins, skill counts, health |
| `/leopoldo repair` | Reinstall missing or corrupted managed skills |
| `/leopoldo rollback` | Restore previous version from snapshot |
| `/leopoldo restore [skill]` | Restore a single replaced skill from backup |
| `/leopoldo remove [slug]` | Remove one plugin, keep shared skills if other plugins need them |
| `/leopoldo uninstall` | Remove all Leopoldo skills, restore originals |

## Manifest

Source of truth for all Leopoldo state in a project.

**Location:** `.claude/skills/.leopoldo-manifest.json` (Claude Code) or `.claude-plugin/skills/.leopoldo-manifest.json` (Cowork)

### Schema

```json
{
  "manifest_version": "1.0.0",
  "format": "claude-code",
  "installed_at": "2026-03-25T14:00:00Z",
  "updated_at": "2026-03-25T14:00:00Z",
  "plugins": {
    "investment-core": {
      "version": "1.0.0",
      "installed_at": "2026-03-25T14:00:00Z"
    },
    "deal-engine": {
      "version": "1.0.0",
      "installed_at": "2026-03-27T10:00:00Z"
    }
  },
  "skills": {
    "dd-screening": {
      "source": "investment-core",
      "shared_with": [],
      "version": "1.0.0",
      "hash": "a1b2c3d4e5f6",
      "status": "managed"
    },
    "systematic-debugging": {
      "source": "common",
      "shared_with": ["investment-core", "deal-engine"],
      "version": "1.2.0",
      "hash": "i9j0k1l2m3n4",
      "status": "managed"
    },
    "my-custom-workflow": {
      "source": "user",
      "status": "preserved"
    },
    "old-analysis-tool": {
      "source": "user",
      "status": "replaced",
      "replaced_by": "deal-engine",
      "backup": ".leopoldo-backup/skills/old-analysis-tool/"
    },
    "some-conflicting-skill": {
      "source": "deal-engine",
      "status": "skipped",
      "reason": "User declined replacement on 2026-03-27"
    }
  }
}
```

### Skill statuses

| Status | Meaning | Update behavior |
|--------|---------|-----------------|
| `managed` | Installed by Leopoldo, we control it | Auto-update if hash unchanged |
| `managed-modified` | Installed by Leopoldo, user edited it | Skip update (notify user) |
| `preserved` | User's own skill, never ours | Never touch |
| `replaced` | User's skill we replaced (backup exists) | N/A (original in backup) |
| `skipped` | User declined installing this skill | Don't ask again |

## Format Detection

Detect project format before any operation:

```
1. Does .claude/skills/ exist? → format = "claude-code"
   skills_dir = ".claude/skills/"

2. Does .claude-plugin/ exist? → format = "cowork"
   skills_dir = ".claude-plugin/skills/"

3. Neither exists? → Ask user which format, then create directory
```

## Workflows

### /leopoldo install [slug]

First-time installation of a Leopoldo plugin into the current project.

**Precondition:** No manifest exists (or manifest exists but this plugin is not in it — in that case, redirect to `/leopoldo add`).

```
Step 1: Detect format
  → claude-code or cowork (see Format Detection above)

Step 2: Check for existing manifest
  → Exists with this plugin? "Already installed. Use /leopoldo update."
  → Exists without this plugin? Redirect to /leopoldo add
  → Doesn't exist? Continue

Step 3: Download plugin
  → GET https://api.github.com/repos/leopoldo-ai/{slug}/releases/latest
  → Download release asset ZIP
  → Extract to temp directory

Step 4: Scan existing skills
  → List all directories in skills_dir
  → Build map: {skill_name: {path, exists: true}}

Step 5: Install skills with conflict resolution
  → For each skill in the downloaded plugin:
    A) Skill name does NOT exist in project:
       → Copy skill to skills_dir
       → Add to manifest as "managed"

    B) Skill name EXISTS in project:
       → CONFLICT. Prompt user:
         "{skill_name} already exists in your project.
          Replace with Leopoldo version? (original will be backed up)
          [y] replace  [n] skip  [a] replace all"
       → y: backup to .leopoldo-backup/skills/{name}/ → copy Leopoldo → managed
       → n: add to manifest as "skipped"
       → a: apply "y" to all remaining conflicts

Step 6: Compute hashes
  → For each managed skill: SHA-256 of SKILL.md content
  → Store in manifest

Step 7: Generate/merge CLAUDE.md
  → See CLAUDE.md Management section below

Step 8: Write manifest
  → Write .leopoldo-manifest.json

Step 9: Create initial snapshot
  → Copy current state to .leopoldo-backup/snapshots/v{version}/

Step 10: Report
  → "Investment Core v1.0.0 installed.
     100 skills added, 2 replaced (backed up), 1 skipped.
     Run /leopoldo status for details."
```

### /leopoldo add [slug]

Add another plugin to a project that already has Leopoldo installed.

**Precondition:** Manifest exists.

```
Step 1: Read manifest
  → Load plugins list and skill map

Step 2: Check if plugin already installed
  → Already in manifest? "Already installed. Use /leopoldo update."

Step 3: Download plugin
  → Same as install Step 3

Step 4: Process skills with dedup and version resolution
  → For each skill in the downloaded plugin:

    A) Skill is already managed (in manifest):
       → Compare versions
       → Downloaded version > installed version?
         → Update skill, update hash and version in manifest
       → Downloaded version <= installed version?
         → Skip (keep the newer one)
       → Add plugin slug to "shared_with" array

    B) Skill is NOT in manifest but EXISTS on disk:
       → It's a user/vendor skill. Same conflict flow as install Step 5.
       → Prompt: replace / skip / all

    C) Skill is NOT in manifest and NOT on disk:
       → New skill. Copy to skills_dir.
       → Add to manifest as "managed"

Step 5: Update manifest
  → Add plugin to plugins map
  → Update skill entries

Step 6: Regenerate CLAUDE.md Leopoldo section

Step 7: Report
  → "Deal Engine v1.0.0 added.
     24 new skills, 80 shared (already installed), 0 conflicts."
```

### /leopoldo update (and auto-update on session start)

Update managed skills to latest version. Runs automatically on session start via update-checker integration, or manually with `/leopoldo update`.

```
Step 1: Read manifest
  → If no manifest exists:
    → MIGRATION: scan all skills, generate manifest with all = managed
    → Notify: "Leopoldo manifest created for safe future updates."
    → Continue

Step 2: Check for new version
  → For each plugin in manifest.plugins:
    → GET https://api.github.com/repos/leopoldo-ai/{slug}/releases/latest
    → Compare tag_name with installed version
  → If all up to date: exit silently (auto) or "All plugins up to date." (manual)

Step 3: Download updated plugins

Step 4: Create snapshot before applying
  → Copy managed skills to .leopoldo-backup/snapshots/v{current_version}/

Step 5: Apply updates with hash protection
  → For each skill in the update:

    A) In manifest as "managed":
       → Compute current file hash
       → Hash matches manifest hash? (user hasn't modified it)
         → YES: overwrite with new version, update hash
         → NO: skill is now "managed-modified"
           → Auto mode: skip, add to skipped list
           → --force mode: backup modified version, overwrite, update hash

    B) In manifest as "skipped":
       → Still skipped. Don't touch.

    C) In manifest as "managed-modified":
       → Auto mode: skip
       → --force mode: backup, overwrite, reset to "managed"

    D) NOT in manifest (new skill in this release):
       → Check if name exists on disk
       → Exists: conflict flow (prompt in manual, skip in auto)
       → Doesn't exist: add, mark as managed

Step 6: Update manifest
  → New versions, new hashes, new skills

Step 7: Regenerate CLAUDE.md Leopoldo section

Step 8: Enforce snapshot cap
  → Keep max 3 snapshots, delete oldest

Step 9: Report
  → Auto mode (session start):
    "Leopoldo updated to v1.1.0"
    If skips: "+ 2 skills skipped (local changes). /leopoldo status for details."
  → Manual mode:
    "Updated to v1.1.0. 45 skills updated, 2 skipped (local changes), 1 new.
     Skipped: dd-screening (modified), risk-framework (modified)
     Use /leopoldo update --force to override."
```

### /leopoldo status

Show complete state of Leopoldo in the current project.

```
Output format:

Leopoldo Status
═══════════════

Plugins installed: 2
  Investment Core  v1.0.0  (installed 2026-03-25)
  Deal Engine      v1.0.0  (installed 2026-03-27)

Skills: 124 total
  Managed:          118  (auto-updated)
  Managed-modified:   2  (local changes, updates skipped)
  Skipped:            1  (user declined)
  User/other:         3  (not managed by Leopoldo)

Modified skills:
  dd-screening       modified 2026-03-26
  risk-framework     modified 2026-03-27

Skipped skills:
  some-tool          declined 2026-03-27

Backups:
  .leopoldo-backup/skills/     2 replaced skills
  .leopoldo-backup/snapshots/  1 version snapshot (v1.0.0)

Health: OK
  All managed skills present. No integrity issues.
```

### /leopoldo repair

Fix missing or corrupted managed skills.

```
Step 1: Read manifest

Step 2: Integrity check
  → For each managed skill:
    → File exists? Hash matches?
    → Missing: add to repair list
    → Hash mismatch without managed-modified status: add to repair list

Step 3: Download current versions of affected skills

Step 4: Reinstall only damaged skills
  → Restore from download
  → Update hashes in manifest

Step 5: Report
  → "Repaired 3 skills: dd-screening, risk-framework, session-lifecycle."
  → or "All skills healthy. Nothing to repair."
```

### /leopoldo rollback

Restore a previous version from snapshot.

```
Step 1: List available snapshots
  → .leopoldo-backup/snapshots/v1.0.0/
  → .leopoldo-backup/snapshots/v0.9.0/

Step 2: User selects version
  → "Available snapshots: v1.0.0, v0.9.0. Rollback to which version?"

Step 3: Confirm
  → "Rollback to v1.0.0? This will overwrite current managed skills. [y/n]"

Step 4: Restore
  → Replace all managed skills with snapshot versions
  → Restore manifest from snapshot
  → Regenerate CLAUDE.md section

Step 5: Report
  → "Rolled back to v1.0.0. Run /leopoldo update when ready to update again."
```

### /leopoldo restore [skill-name]

Restore a single skill that was replaced during install.

```
Step 1: Check manifest for skill with status "replaced"
  → Not found? "No backup found for {skill-name}."

Step 2: Confirm
  → "Restore original {skill-name} and remove Leopoldo version? [y/n]"

Step 3: Restore
  → Copy from .leopoldo-backup/skills/{name}/ back to skills_dir
  → Update manifest: remove skill entry (or mark as "restored")
  → The Leopoldo skill is removed from the project

Step 4: Report
  → "Restored original {skill-name}. Leopoldo version removed."
```

### /leopoldo remove [slug]

Remove a single plugin while keeping shared skills if other plugins need them.

```
Step 1: Read manifest

Step 2: Identify skills to remove
  → For each skill with source = {slug}:
    → Is it shared_with other installed plugins? → Keep it
    → Is it unique to this plugin? → Remove it
  → For shared skills (common, engine):
    → Other plugins still installed? → Keep
    → No other plugins? → Remove

Step 3: Remove skills
  → Delete skill directories for unique skills
  → Update manifest: remove plugin, remove unique skills

Step 4: Restore backed-up skills if applicable
  → If any replaced skills were from this plugin and user wants them back

Step 5: Regenerate CLAUDE.md section

Step 6: Report
  → "Deal Engine removed. 20 skills removed, 80 shared skills kept.
     Investment Core still installed."
```

### /leopoldo uninstall

Complete removal of all Leopoldo from the project.

```
Step 1: Confirm
  → "Remove ALL Leopoldo skills and restore original skills? [y/n]"

Step 2: Restore replaced skills
  → For each skill with status "replaced":
    → Copy from .leopoldo-backup/skills/{name}/ back to skills_dir

Step 3: Remove all managed skills
  → For each skill with status "managed" or "managed-modified":
    → Delete skill directory

Step 4: Remove Leopoldo section from CLAUDE.md
  → Find <!-- leopoldo:start --> and <!-- leopoldo:end -->
  → Delete everything between (inclusive)
  → If CLAUDE.md is now empty, delete it

Step 5: Clean up
  → Delete manifest
  → Delete .leopoldo-backup/
  → Delete VERSION.json (if it's ours)

Step 5b: Imprint data (Protected Directory Rule)
  → If .leopoldo/imprint/ exists:
    → "Delete Imprint learning data too? [y/N]"
    → y: delete .leopoldo/ directory
    → N (default): keep .leopoldo/ intact

Step 6: Report
  → "Leopoldo removed. 3 original skills restored. Project is clean."
```

## CLAUDE.md Management

### Markers

The Leopoldo section is delimited by HTML comments:

```markdown
<!-- leopoldo:start -->
## Leopoldo
...managed content...
<!-- leopoldo:end -->
```

### Rules

| Situation | Action |
|-----------|--------|
| CLAUDE.md doesn't exist | Generate complete file from template |
| CLAUDE.md exists, no markers | Append markers + section at the end |
| CLAUDE.md exists, markers present | Replace content between markers only |
| Everything outside markers | NEVER read, modify, or delete |

### Section template

```markdown
<!-- leopoldo:start -->
## Leopoldo

> Auto-managed by Leopoldo v{version}. Do not edit between these markers.

### Installed plugins

{plugin_table}

### Available agents

{agent_table}

### Workflow

1. State your goal or use a domain command
2. For complex decisions: use /board (multi-perspective consultation)
3. Domain skills handle analysis, reporting skills handle deliverables

### Conventions

- Traffic lights: green on track | yellow needs attention | red critical
- Status: possible now | requires setup | future roadmap
- Tables and matrices for data comparison
- Executive summary for outputs over 500 words
- Actionable recommendations and next steps

### Commands

| Command | Purpose |
|---------|---------|
| /leopoldo status | Show installed plugins and health |
| /leopoldo update | Check for updates |
| /board | Multi-perspective consultation |

<!-- leopoldo:end -->
```

## Hook Management

Hooks are system components that ship with every Leopoldo installation. Unlike skills, hooks are not customizable by users.

### Hook Files

| Script | Hook Event | Purpose |
|--------|-----------|---------|
| `core.sh` | (shared library) | Project root discovery, gate state, journal helpers |
| `session-start.sh` | SessionStart | Initialize session, load Imprint, check evolution |
| `correction-detector.sh` | UserPromptSubmit | Detect correction signals, set postmortem gate |
| `gate-enforcer.sh` | Stop | Enforce pending gates, block if unresolved |
| `pre-edit-validator.sh` | PreToolUse | Protect .state/ and .leopoldo/ from accidental writes |
| `tool-logger.sh` | PostToolUse | Log tool usage, track checkpoint counter |

### Install Flow (hooks)

During `/leopoldo install`:

1. Copy `.leopoldo/hooks/` directory (6 scripts) from plugin package
2. Make all scripts executable: `chmod +x .leopoldo/hooks/*.sh`
3. Merge hooks into `.claude/settings.json` (see merge logic below)
4. Record hook versions in manifest under `"hooks"` key

### Settings.json Merge

Like CLAUDE.md, settings.json must be merged non-destructively:

1. Read existing `.claude/settings.json` (create if missing)
2. If no `"hooks"` key exists, add the full hooks block from template
3. If `"hooks"` key exists with Leopoldo hooks, update them in place
4. If `"hooks"` key exists with user hooks (non-Leopoldo), preserve them and append Leopoldo hooks to each event array
5. Never touch `permissions`, `agent`, or other user settings outside `hooks`

Detection: Leopoldo hooks are identified by command containing `.leopoldo/hooks/`.

### Update Flow (hooks)

During `/leopoldo update`:

1. Create snapshot of current `.leopoldo/hooks/`
2. Download updated hook scripts
3. Overwrite all scripts (hooks are system-managed)
4. Verify executability (`chmod +x`)
5. Update hooks hash in manifest

### Remove Flow (hooks)

During `/leopoldo uninstall`:

1. Remove Leopoldo hooks from `.claude/settings.json` (identified by `.leopoldo/hooks/` in command)
2. If no hooks remain in an event, remove the event key
3. If no events remain, remove the `"hooks"` key entirely
4. Remove `.leopoldo/hooks/` directory
5. Remove `.state/` directory
6. Remove `.leopoldo/` directory (after confirming with user if Imprint profile exists)

### Manifest Hooks Entry

```json
{
  "hooks": {
    "version": "1.0.0",
    "hash": "<sha256 of all hook files concatenated>",
    "scripts": ["core.sh", "session-start.sh", "correction-detector.sh", "gate-enforcer.sh", "pre-edit-validator.sh", "tool-logger.sh"],
    "settings_merged": true
  }
}
```

## Integrity Check (Session Start)

Runs automatically, lightweight, every session start:

```
1. Manifest exists?
   → No: check if Leopoldo skills are present (migration scenario)
     → Skills found without manifest: generate manifest
     → No skills: exit (not a Leopoldo project)
   → Yes: continue

2. Quick integrity scan:
   → Count managed skills in manifest
   → Check file existence (NOT hash — too slow for session start)
   → Missing files? Warn: "2 Leopoldo skills missing. Run /leopoldo repair."

3. Version check:
   → Delegate to update-checker (now manifest-aware)
```

## Version Conflict Resolution

When two plugins bring the same skill at different versions:

```
Rule: highest version wins.

Plugin A brings systematic-debugging v1.2.0 (already installed)
Plugin B brings systematic-debugging v1.0.0

→ Keep v1.2.0 (already installed, higher version)
→ Add Plugin B to shared_with list
→ Don't downgrade

Plugin A has systematic-debugging v1.0.0 (already installed)
Plugin B brings systematic-debugging v1.2.0

→ Upgrade to v1.2.0
→ Update hash in manifest
→ Add Plugin B to shared_with list
```

## Snapshot Management

```
Location: .leopoldo-backup/snapshots/

Structure:
  v1.0.0/
    manifest.json       ← manifest at that version
    skills/             ← all managed skill files

Cap: 3 snapshots maximum.
When creating 4th: delete oldest.

Created automatically:
  - Before every /leopoldo update
  - Before every /leopoldo install (initial state)
```

## Protected Directories

`.leopoldo/` is a protected directory containing user data (Imprint profile, observations, config). No manager operation touches it.

### Protection Matrix

| Operation | `.claude/skills/imprint/` (code) | `.leopoldo/imprint/` (data) |
|-----------|----------------------------------|----------------------------|
| `/leopoldo update` | Updates SKILL.md | Never touched |
| `/leopoldo repair` | Restores SKILL.md | Never touched |
| `/leopoldo remove` | Removes skill | Never touched |
| `/leopoldo uninstall` | Removes all skills | Asks confirmation (see below) |
| `/imprint reset` | Does not touch | Deletes profile + observations |

### Pre-Update Backup

Before any update operation, if `.leopoldo/imprint/profile.json` exists and is not empty (`{}`):
1. Copy to `.leopoldo-backup/imprint/profile-{YYYY-MM-DD-HHMMSS}.json`
2. Enforce max 3 backups: delete oldest if exceeded

### Uninstall Confirmation

When running `/leopoldo uninstall`, after the standard confirmation:
1. Check if `.leopoldo/imprint/` exists
2. If yes, ask: "Delete Imprint learning data too? Your profile and observations will be permanently removed. [y/N]"
3. Default: No (keep the data)
4. If yes: delete `.leopoldo/` directory
5. If no: `.leopoldo/` stays. User can manually delete later.

## Error Handling

| Error | Action |
|-------|--------|
| No network | "Cannot reach GitHub. Check connection." (manual) / silent (auto) |
| Plugin not found | "Plugin '{slug}' not found. Check the name." |
| Manifest corrupted | Regenerate from disk scan, warn user |
| Disk full | "Cannot write files. Check disk space." |
| Permission denied | "Cannot write to {path}. Check permissions." |
| Hash computation fails | Treat as unmodified (safe default) |

## Anti-patterns

- Touching files outside skills_dir without explicit user request
- Modifying content above `<!-- leopoldo:start -->` in CLAUDE.md
- Auto-updating skills the user has modified (without --force)
- Asking questions during automatic session-start operations
- Deleting user skills without explicit confirmation
- Overwriting a higher version skill with a lower version
- Running install when manifest already has the plugin (redirect to add/update)

## Integration with Other Engine Skills

| Skill | Integration |
|-------|-------------|
| `update-checker` | Delegates to manager for manifest-aware updates |
| `leopoldo-setup` | First-time setup delegates to manager install flow |
| `imprint` | Reads manifest to know which plugins are active |
| `session-lifecycle` | Triggers integrity check on session start |
| `skill-postmortem` | Correction events tagged with managed/user skill source |

---

**Version:** 1.0.0
**Type:** Engine skill (distributed in every plugin)
**Dependencies:** Read/Write tools, WebFetch (for GitHub API), Bash (for file operations)
