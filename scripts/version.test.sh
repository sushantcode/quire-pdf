#!/usr/bin/env bash
# What `version.sh` says, against a repository built to say it.
#
# The patch is derived from history, so the only honest way to check it is to
# make some history. Each case builds a throwaway repository, because the
# question being asked — "does the count reset?" — is a question about commits
# and cannot be asked of a fixture.
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/version.sh"
failures=0

# A repository with the script at the path it expects, relative to itself.
new_repo() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/scripts"
  cp "$script" "$dir/scripts/version.sh"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.invalid"
  git -C "$dir" config user.name "Version Test"
  echo "$dir"
}

commit() {  # repo, message
  git -C "$1" commit -q --allow-empty -m "$2"
}

set_series() {  # repo, series
  echo "$2" > "$1/VERSION"
  git -C "$1" add VERSION
  git -C "$1" commit -q -m "set version to $2"
}

check() {  # repo, expected, what
  local got
  got="$(cd "$1" && ./scripts/version.sh 2>&1)" || got="FAILED: $got"
  if [[ "$got" != "$2" ]]; then
    echo "  ✘ $3: expected '$2', got '$got'" >&2
    failures=$((failures + 1))
  else
    echo "  ✔ $3 — $got"
  fi
}

echo "counting from the commit that set the version"
repo="$(new_repo)"
commit "$repo" "something before there was a version"
set_series "$repo" "0.1"
check "$repo" "0.1.0" "the commit that sets the version is .0"
commit "$repo" "a change"
commit "$repo" "another"
check "$repo" "0.1.2" "each commit after it adds one"

echo
echo "resetting when the series changes"
set_series "$repo" "0.2"
check "$repo" "0.2.0" "bumping the minor resets the patch"
commit "$repo" "a change on the new minor"
check "$repo" "0.2.1" "and it counts again from there"
set_series "$repo" "1.0"
check "$repo" "1.0.0" "bumping the major resets it too"

echo
echo "not counting merges"
repo="$(new_repo)"
set_series "$repo" "0.1"
check "$repo" "0.1.0" "the release commit is .0"
# A branch with one change on it, merged with a merge commit — which is how
# every one of these lands. The merge is bookkeeping; the change is the change.
git -C "$repo" checkout -q -b a-change
commit "$repo" "the change"
git -C "$repo" checkout -q -
git -C "$repo" merge -q --no-ff -m "Merge pull request #1 from a-change" a-change
check "$repo" "0.1.1" "a merged branch of one commit adds one, not two"

echo
echo "refusing rather than guessing"
repo="$(new_repo)"
commit "$repo" "no version file at all"
check "$repo" "FAILED: no VERSION file at $repo/VERSION" "says so when there is no VERSION"

repo="$(new_repo)"
# A patch in the file is the mistake this is most likely to meet: someone
# writes the whole version in, and the derived patch silently disagrees with
# the one they wrote.
set_series "$repo" "0.1.4"
check "$repo" \
  "FAILED: VERSION must be MAJOR.MINOR — found '0.1.4'
the patch is derived from the history and does not belong in the file" \
  "refuses a version with a patch already in it"

repo="$(new_repo)"
echo "0.1" > "$repo/VERSION"
check "$repo" \
  "FAILED: cannot derive the patch: no commit for VERSION in this checkout" \
  "refuses when VERSION is not committed"

echo
if (( failures > 0 )); then
  echo "$failures version check(s) failed" >&2
  exit 1
fi
echo "version.sh behaves"
