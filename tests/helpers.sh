#!/usr/bin/env bash
#
# Shared assertions and fixtures for the Limon test suite.
# Copyright (C) 2026 Farid Rasidov
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Resolve the repo root from this file's location so tests can be run from anywhere.
LIMON_TEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIMON_REPO_ROOT="$( cd "$LIMON_TEST_DIR/.." && pwd )"
export LIMON_TEST_DIR LIMON_REPO_ROOT

_LIMON_T_PASS=0
_LIMON_T_FAIL=0
_LIMON_T_SKIP=0
_LIMON_T_CURRENT="(none)"

# --- Output -----------------------------------------------------------------

_limon_t_red()    { printf '\033[31m%s\033[0m' "$1"; }
_limon_t_green()  { printf '\033[32m%s\033[0m' "$1"; }
_limon_t_yellow() { printf '\033[33m%s\033[0m' "$1"; }

# it <description> — names the assertions that follow.
it() {
    _LIMON_T_CURRENT="$1"
}

_limon_t_ok() {
    _LIMON_T_PASS=$((_LIMON_T_PASS + 1))
    printf '  %s %s\n' "$(_limon_t_green 'ok')" "$_LIMON_T_CURRENT"
}

# Report a failure with expected/actual detail, then keep going so one broken
# assertion does not hide the rest of the file.
_limon_t_not_ok() {
    _LIMON_T_FAIL=$((_LIMON_T_FAIL + 1))
    printf '  %s %s\n' "$(_limon_t_red 'FAIL')" "$_LIMON_T_CURRENT"
    local line
    for line in "$@"; do
        printf '       %s\n' "$line"
    done
}

# skip <reason> — the case could not run here. Counted separately and never as
# a pass: a dependency that is missing locally but present in CI must not read
# as green, or the only test for a feature can stop running unnoticed.
skip() {
    _LIMON_T_SKIP=$((_LIMON_T_SKIP + 1))
    printf '  %s %s\n' "$(_limon_t_yellow 'skip')" "$_LIMON_T_CURRENT"
    [[ -n "${1:-}" ]] && printf '       %s\n' "$1"
    return 0
}

# --- Assertions -------------------------------------------------------------

assert_eq() {
    local expected="$1" actual="$2"
    if [[ "$expected" == "$actual" ]]; then
        _limon_t_ok
    else
        _limon_t_not_ok "expected: [$expected]" "actual:   [$actual]"
    fi
}

assert_ne() {
    local unexpected="$1" actual="$2"
    if [[ "$unexpected" != "$actual" ]]; then
        _limon_t_ok
    else
        _limon_t_not_ok "expected value to differ from: [$unexpected]"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2"
    if [[ "$haystack" == *"$needle"* ]]; then
        _limon_t_ok
    else
        _limon_t_not_ok "expected to contain: [$needle]" "in:                  [$haystack]"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2"
    if [[ "$haystack" != *"$needle"* ]]; then
        _limon_t_ok
    else
        _limon_t_not_ok "expected NOT to contain: [$needle]" "in:                      [$haystack]"
    fi
}

# assert_ok <command...> — the command must exit 0.
assert_ok() {
    local out
    if out="$("$@" 2>&1)"; then
        _limon_t_ok
    else
        _limon_t_not_ok "expected success from: $*" "exit:   $?" "output: $out"
    fi
}

# assert_fail <command...> — the command must exit non-zero.
assert_fail() {
    local out
    if out="$("$@" 2>&1)"; then
        _limon_t_not_ok "expected failure from: $*" "output: $out"
    else
        _limon_t_ok
    fi
}

# --- Fixtures ---------------------------------------------------------------

# Load limon.sh for its functions only — no subcommand dispatch, no config write,
# no prompt installation. See the LIMON_SOURCE_ONLY hook in limon.sh.
load_limon() {
    LIMON_SOURCE_ONLY=1 source "$LIMON_REPO_ROOT/limon.sh"
}

# Point HOME and XDG_CONFIG_HOME at a scratch dir so tests never touch the real
# user's config. Every test file gets a fresh one from run.sh.
use_temp_home() {
    LIMON_TEST_HOME="$(mktemp -d)"
    export HOME="$LIMON_TEST_HOME"
    export XDG_CONFIG_HOME="$LIMON_TEST_HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME"
}

# make_repo <dir> — a git repo with one commit, deterministic identity, and a
# branch name that does not depend on the host's init.defaultBranch setting.
make_repo() {
    local dir="$1"
    mkdir -p "$dir"
    git -C "$dir" init --quiet
    git -C "$dir" checkout -q -b master 2>/dev/null || true
    git -C "$dir" config user.email "test@limon.invalid"
    git -C "$dir" config user.name "Limon Test"
    git -C "$dir" config commit.gpgsign false
    echo "initial" > "$dir/README"
    git -C "$dir" add README
    git -C "$dir" commit -qm "initial"
}

# Cleanup registered by run.sh.
cleanup_temp_home() {
    [[ -n "${LIMON_TEST_HOME:-}" && -d "$LIMON_TEST_HOME" ]] && rm -rf "$LIMON_TEST_HOME"
    return 0
}

# --- Exit -------------------------------------------------------------------

# Called at the end of every test file; run.sh reads the exit status.
finish() {
    if [[ "$_LIMON_T_SKIP" -gt 0 ]]; then
        printf '  %d passed, %d failed, %d skipped\n' \
            "$_LIMON_T_PASS" "$_LIMON_T_FAIL" "$_LIMON_T_SKIP"
    else
        printf '  %d passed, %d failed\n' "$_LIMON_T_PASS" "$_LIMON_T_FAIL"
    fi
    cleanup_temp_home
    [[ "$_LIMON_T_FAIL" -eq 0 ]]
}
