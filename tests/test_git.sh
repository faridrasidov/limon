#!/usr/bin/env bash
# _limon_git_info porcelain parsing against real fixture repos.
# SPDX-License-Identifier: GPL-3.0-or-later

# Options below are read by limon.sh once sourced, and '~' is a literal
# display character in expected prompt output, so these do not apply here.
# shellcheck disable=SC2034,SC2088,SC2154

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home
load_limon

WORK="$HOME/repos"
mkdir -p "$WORK"

# _limon_git_info caches on PWD for 1s; tests move between repos faster than
# that, so clear the cache before each scenario.
reset_git_cache() {
    unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
          __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
          __LIMON_GIT_CACHE_DETACHED __LIMON_STASH_CACHE __LIMON_STASH_CACHE_SEC
}

# scan <dir> [git_mode] — run the parser in <dir> and leave results in globals.
scan() {
    cd "$1" || exit 1
    LIMON_GIT_MODE="${2:-full}"
    reset_git_cache
    _limon_git_info
}

# --- outside a repo ---

it "reports not-in-repo outside a git repository"
scan "$HOME"
assert_eq "0" "$__LIMON_GIT_IN_REPO"

# --- clean repo ---

make_repo "$WORK/clean"
scan "$WORK/clean"

it "detects being inside a repo"
assert_eq "1" "$__LIMON_GIT_IN_REPO"
it "reads the branch name"
assert_eq "master" "$__LIMON_GIT_BRANCH"
it "shows no marks for a clean tree"
assert_eq "" "$__LIMON_GIT_MARKS"
it "is not detached on a branch"
assert_eq "0" "$__LIMON_GIT_DETACHED"

# --- dirty states, verbose mode gives exact counts ---

make_repo "$WORK/staged"
echo "new" > "$WORK/staged/added"
git -C "$WORK/staged" add added
scan "$WORK/staged" verbose
it "counts a staged file as +1"
assert_contains "$__LIMON_GIT_MARKS" "+1"

make_repo "$WORK/unstaged"
echo "changed" >> "$WORK/unstaged/README"
scan "$WORK/unstaged" verbose
it "counts an unstaged edit as ~1"
assert_contains "$__LIMON_GIT_MARKS" "~1"

make_repo "$WORK/untracked"
echo "x" > "$WORK/untracked/loose"
scan "$WORK/untracked" verbose
it "counts an untracked file as ?1"
assert_contains "$__LIMON_GIT_MARKS" "?1"
it "does not count an untracked file as staged"
assert_not_contains "$__LIMON_GIT_MARKS" "+1"

# --- full mode collapses counts to indicators ---

scan "$WORK/staged" full
it "full mode shows the dirty indicator instead of counts"
assert_contains "$__LIMON_GIT_MARKS" "(@)"
it "full mode omits exact counts"
assert_not_contains "$__LIMON_GIT_MARKS" "+1"

scan "$WORK/untracked" full
it "full mode marks untracked files with ?"
assert_contains "$__LIMON_GIT_MARKS" "?"

# --- lite / off modes ---

scan "$WORK/staged" lite
it "lite mode still reports the branch"
assert_eq "master" "$__LIMON_GIT_BRANCH"
it "lite mode emits no marks"
assert_eq "" "$__LIMON_GIT_MARKS"

scan "$WORK/staged" off
it "off mode reports not-in-repo"
assert_eq "0" "$__LIMON_GIT_IN_REPO"

# --- detached HEAD ---

make_repo "$WORK/detached"
echo "second" > "$WORK/detached/f2"
git -C "$WORK/detached" add f2
git -C "$WORK/detached" commit -qm second
git -C "$WORK/detached" checkout -q --detach HEAD~1
scan "$WORK/detached"
it "flags a detached HEAD"
assert_eq "1" "$__LIMON_GIT_DETACHED"
it "marks a detached HEAD in the output"
assert_contains "$__LIMON_GIT_MARKS" "DETACHED"

# --- repo with no commits yet ---

mkdir -p "$WORK/empty"
git -C "$WORK/empty" init --quiet
git -C "$WORK/empty" checkout -q -b master 2>/dev/null || true
scan "$WORK/empty"
it "handles a repo with no commits yet"
assert_eq "1" "$__LIMON_GIT_IN_REPO"
it "still reports a branch name with no commits"
assert_ne "" "$__LIMON_GIT_BRANCH"

# --- ahead / behind a remote ---

make_repo "$WORK/origin"
git clone -q "$WORK/origin" "$WORK/cloned"
git -C "$WORK/cloned" config user.email "test@limon.invalid"
git -C "$WORK/cloned" config user.name "Limon Test"
echo "ahead" > "$WORK/cloned/ahead.txt"
git -C "$WORK/cloned" add ahead.txt
git -C "$WORK/cloned" commit -qm ahead
scan "$WORK/cloned"
it "shows the ahead count"
assert_contains "$__LIMON_GIT_MARKS" "↑1"

# --- stash ---

make_repo "$WORK/stashed"
echo "wip" >> "$WORK/stashed/README"
git -C "$WORK/stashed" stash -q
scan "$WORK/stashed"
it "shows the stash count"
assert_contains "$__LIMON_GIT_MARKS" "≡1"

# --- in-progress operations ---

make_repo "$WORK/merging"
git -C "$WORK/merging" checkout -q -b other
echo "theirs" > "$WORK/merging/README"
git -C "$WORK/merging" commit -qam theirs
git -C "$WORK/merging" checkout -q master
echo "ours" > "$WORK/merging/README"
git -C "$WORK/merging" commit -qam ours
git -C "$WORK/merging" merge other -q >/dev/null 2>&1
scan "$WORK/merging"
it "reports an in-progress merge"
assert_contains "$__LIMON_GIT_MARKS" "MERGING"

# --- ascii mode rewrites the unicode marks ---

scan "$WORK/cloned" full
marks_unicode="$__LIMON_GIT_MARKS"
cd "$WORK/cloned" || exit 1
LIMON_ASCII=1
reset_git_cache
_limon_git_info
it "ascii mode replaces ↑ with ^"
assert_contains "$__LIMON_GIT_MARKS" "^1"
it "ascii mode leaves no unicode arrows behind"
assert_not_contains "$__LIMON_GIT_MARKS" "↑"
it "unicode mode was using the arrow to begin with"
assert_contains "$marks_unicode" "↑"
LIMON_ASCII=0

finish
