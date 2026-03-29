# Release

Unified release pipeline for Leopoldo. One command to validate, build, publish, and release everything.

## Full Pipeline

```
/release [patch|minor|major]
```

If bump type not specified, prompt the user.

### Phase 1 — Pre-flight

1. **Current version**: Read latest git tag (`git describe --tags --abbrev=0`) or default `v0.0.0`
2. **Changelog**: Summarize commits since last release tag (`git log <last-tag>..HEAD --oneline`)
3. **Coherence check**: Run `./distribution/scripts/validate-coherence.sh` if it exists. Block on errors.
4. **Show summary**: Display changelog, current version, proposed new version. Ask for confirmation.

### Phase 2 — Build

5. **Build plugin repos**: Run `./distribution/scripts/build-public-repos.sh`
   - Builds all 11 plugins for Claude Code + Cowork formats
   - Output in `distribution/output/`
6. **Build public monorepo**: Run `./distribution/scripts/build-public-monorepo.sh <monorepo-path>`
   - The monorepo path is the local clone of `leopoldo-ai/leopoldo.ai`
   - Default path: `../leopoldo.ai` (sibling directory). If not found, ask the user.
7. **Verify build output**: Check that `distribution/output/claude-code/plugins/` contains all expected plugins

### Phase 3 — Version and Tag

8. **Bump version**: Calculate new version from bump type
9. **Commit**: `git add -A && git commit -m "release: vX.Y.Z"`
10. **Tag**: `git tag vX.Y.Z`

### Phase 4 — Push and Publish

11. **Push private repo**: `git push origin master && git push origin --tags`
12. **Push monorepo**: `cd <monorepo-path> && git add -A && git commit -m "release: vX.Y.Z" && git push origin master`
13. **GitHub Release**: `gh release create vX.Y.Z --title "vX.Y.Z" --notes "<changelog>"` on the private repo
14. **Publish to backend** (optional): If `LEOPOLDO_ADMIN_KEY` is set, publish plugin ZIPs to backend API

### Phase 5 — Verify

15. **Post-release check**: Verify tag exists on remote, GitHub Release is live
16. **Report**: Print summary of what was released

## Safety Gates

- **Before build**: Show changelog and ask for confirmation
- **Before push**: Show what will be pushed (commits, files changed) and ask for confirmation
- **On error**: Stop immediately, do not proceed to push if build fails

## Rules

- Always show the changelog before creating the release
- Never skip the build verification step
- Include skill count and plugin list in release notes
- Version format: `vX.Y.Z`
- If any phase fails, stop and report. Do not continue to the next phase.
- The monorepo push is a separate git repo. Handle it carefully (cd in, commit, push, cd back).
- Never force push. If push fails, diagnose and report.
