#!/usr/bin/env bash
# _limon_display_path: home collapsing, truncation, and termination.
# SPDX-License-Identifier: GPL-3.0-or-later

# Options below are read by limon.sh once sourced, and '~' is a literal
# display character in expected prompt output, so these do not apply here.
# shellcheck disable=SC2034,SC2088,SC2154

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home
load_limon

mkdir -p "$HOME/projects/limon"
DEEP="$HOME/a/very/deeply/nested/path/structure/here"
mkdir -p "$DEEP"

# --- home collapsing (max=0 disables truncation) ---

cd "$HOME" || exit 1
it "collapses \$HOME itself to ~"
assert_eq "~" "$(_limon_display_path 0)"

cd "$HOME/projects/limon" || exit 1
it "collapses a path under \$HOME to ~/..."
assert_eq "~/projects/limon" "$(_limon_display_path 0)"

cd /tmp || exit 1
it "leaves a path outside \$HOME absolute"
assert_eq "/tmp" "$(_limon_display_path 0)"

cd "$HOME/projects/limon" || exit 1
it "does not truncate when the path already fits"
assert_eq "~/projects/limon" "$(_limon_display_path 40)"

it "treats a non-numeric max as no limit"
assert_eq "~/projects/limon" "$(_limon_display_path "abc")"

# --- truncation invariants ---
#
# Exact widths depend on the locale ("…" is one char but three bytes, and bash's
# ${#var} follows the locale), so these assert structural invariants that hold
# either way rather than pinning exact strings.

cd "$DEEP" || exit 1

it "truncation keeps the final component visible"
assert_contains "$(_limon_display_path 15)" "here"

it "truncation marks elision with the ellipsis"
assert_contains "$(_limon_display_path 15)" "…"

it "truncation drops interior components"
assert_not_contains "$(_limon_display_path 15)" "deeply"

it "a generous limit leaves the path untouched"
assert_eq "~/a/very/deeply/nested/path/structure/here" "$(_limon_display_path 100)"

# --- regression: these used to loop forever ---
#
# The old implementation shrank the tail with "${tail#*/}", but tail was already
# a basename containing no "/", so the loop could never make progress. Any
# max_path small enough to trigger it froze the shell on every prompt render.

for max in 1 2 3 4 5 6 8 9 10 12; do
    it "max=$max terminates and produces non-empty output"
    out="$(timeout 5 bash -c "
        LIMON_SOURCE_ONLY=1 source '$LIMON_REPO_ROOT/limon.sh'
        export HOME='$HOME'
        cd '$DEEP' || exit 1
        _limon_display_path $max
    ")"
    rc=$?
    if [[ $rc -eq 124 ]]; then
        _LIMON_T_CURRENT="max=$max terminates (HUNG — infinite loop regression)"
        _limon_t_not_ok "_limon_display_path $max did not return within 5s"
    else
        assert_ne "" "$out"
    fi
done

it "never returns empty for a single overlong component"
cd "$HOME" || exit 1
mkdir -p "$HOME/averyveryverylongsingledirectorynamehere"
cd "$HOME/averyveryverylongsingledirectorynamehere" || exit 1
assert_ne "" "$(_limon_display_path 5)"

finish
