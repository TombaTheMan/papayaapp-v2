#!/usr/bin/env bash
# Auto-commit every change in the project and push it to the remote.
# Wired as a Stop hook in .claude/settings.json so it runs after each
# Claude Code session. Safe to run by hand too.
#
#   - Stages everything (git add -A)
#   - Commits only when something actually changed
#   - Pushes only when a git remote exists; never fails the session if push fails
set -u

repo="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "${repo}" ] && exit 0
cd "${repo}" || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0   # not a git repo yet

git add -A
git diff --cached --quiet && exit 0                 # nothing to commit

ts="$(date '+%Y-%m-%d %H:%M:%S')"
git commit --no-verify -m "Auto-commit: ${ts}

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" >/dev/null || exit 0

if git remote | grep -q .; then
  branch="$(git branch --show-current)"
  git push -u origin "${branch}" >/dev/null 2>&1 || git push >/dev/null 2>&1 || true
fi
exit 0
