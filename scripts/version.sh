#!/usr/bin/env bash
# Print this build's version, as MAJOR.MINOR.PATCH.
#
# MAJOR and MINOR are decided by a person and live in `VERSION` at the root of
# the repository. PATCH is not stored anywhere: it is the number of commits
# since `VERSION` last changed. That is what makes it reset — bumping the minor
# is a commit to that file, so the count starts again from it, and the commit
# that bumps it is `.0`.
#
# Deriving it rather than storing it means there is no counter to forget to
# increment, no merge conflict on a version line, and no way for the number to
# disagree with the history it is supposed to describe.
#
# Printed without a leading `v`. Apple requires CFBundleShortVersionString to be
# numeric, so a prefix belongs to the screens, not to the build.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
file="$root/VERSION"

if [[ ! -f "$file" ]]; then
  echo "no VERSION file at $file" >&2
  exit 1
fi

series="$(tr -d '[:space:]' < "$file")"
if [[ ! "$series" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be MAJOR.MINOR — found '$series'" >&2
  echo "the patch is derived from the history and does not belong in the file" >&2
  exit 1
fi

# The commit that last touched VERSION. The file holds nothing but the version,
# so any change to it is a version change; there is no edit that should not
# reset the count.
if ! sha="$(git -C "$root" log -1 --format=%H -- VERSION 2>/dev/null)" || [[ -z "$sha" ]]; then
  # No git, or a clone shallow enough that the change is not in it. Saying so
  # beats inventing a patch number that would be wrong in a way nothing checks.
  echo "cannot derive the patch: no commit for VERSION in this checkout" >&2
  exit 1
fi

# `--no-merges`, because a merge commit is bookkeeping rather than a change.
# Counting it meant the version on a branch and the version on main after
# merging that branch were different numbers: the release commit that set
# `VERSION` was `.0`, and main one merge later was `.1`, so the `.0` of any
# series existed only on a branch and never on main.
echo "$series.$(git -C "$root" rev-list --count --no-merges "$sha..HEAD")"
