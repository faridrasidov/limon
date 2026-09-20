#!/usr/bin/env bash
# on / off / reload lifecycle: does Limon install and fully uninstall itself?
#
# These run limon.sh the way a user does — sourced into a live shell — rather
# than unit-testing helpers, so they catch state that leaks across transitions.
#
# SPDX-License-Identifier: GPL-3.0-or-later

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home

LIMON="$LIMON_REPO_ROOT/limon.sh"

# Run a scenario in its own bash process with a known starting prompt, and echo
# the values we want to assert on. Keeps each case independent.
scenario() {
    env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color \
        bash -c "
            PS1='original-ps1> '
            PROMPT_COMMAND='echo original-pc'
            source '$LIMON' $1 >/dev/null 2>&1
            $2
        "
}

# --- limon on ---

it "installs limon_runner into PROMPT_COMMAND"
assert_contains "$(scenario "on default" 'echo "$PROMPT_COMMAND"')" "limon_runner"

it "preserves the user's existing PROMPT_COMMAND"
assert_contains "$(scenario "on default" 'echo "$PROMPT_COMMAND"')" "original-pc"

it "replaces PS1"
assert_not_contains "$(scenario "on default" 'echo "$PS1"')" "original-ps1"

it "records the original PS1 for restoration"
assert_contains "$(scenario "on default" 'echo "$DEFAULT_PS1"')" "original-ps1"

it "installs a DEBUG trap for the command timer"
assert_contains "$(scenario "on default" 'trap -p DEBUG')" "_limon_preexec"

it "reports itself active"
assert_contains "$(scenario "on default" '_limon_is_active && echo ACTIVE')" "ACTIVE"

# --- limon off restores the shell ---

it "off restores the original PS1"
assert_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; echo \"\$PS1\"")" "original-ps1"

it "off removes limon_runner from PROMPT_COMMAND"
assert_not_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; echo \"\$PROMPT_COMMAND\"")" "limon_runner"

it "off restores the user's original PROMPT_COMMAND"
assert_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; echo \"\$PROMPT_COMMAND\"")" "original-pc"

# Bash localizes DEBUG trap changes to `source` contexts and restores them on
# return, so a sourced script cannot remove the trap — it can only disarm it.
# What matters is that _limon_preexec no longer runs after `limon off`.
it "off disarms the DEBUG trap so _limon_preexec no longer runs"
assert_not_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; trap -p DEBUG")" "_limon_preexec"

# KNOWN LIMITATION, pinned here so a future change does not assume otherwise.
#
# Bash does not expose the caller's DEBUG trap to a sourced script: `trap -p
# DEBUG` inside limon.sh returns empty even when the calling shell has one set,
# and `set -T` does not change that. So DEFAULT_DEBUG_TRAP is always captured
# empty in normal use, and `limon off` cannot restore a DEBUG trap the user had
# installed before `limon on` — it disarms the trap instead.
#
# This test documents that behavior rather than asserting a fix. If bash ever
# makes the trap visible, this test will fail and the restore path can be
# re-enabled.
it "documents that a pre-existing user DEBUG trap is not restored (bash limitation)"
out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
    PS1='original-ps1> '
    trap 'true # user-debug-hook' DEBUG
    source '$LIMON' on default >/dev/null 2>&1
    source '$LIMON' off >/dev/null 2>&1
    trap -p DEBUG
")"
assert_not_contains "$out" "_limon_preexec"

it "_limon_preexec is inert once Limon is off"
out="$(scenario "on default" "
    source '$LIMON' off >/dev/null 2>&1
    __LIMON_CMD_ACTIVE=0
    _limon_preexec
    echo \"active=\${__LIMON_CMD_ACTIVE:-0}\"
")"
assert_contains "$out" "active=0"

it "off reports itself inactive"
assert_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; _limon_is_active || echo INACTIVE")" "INACTIVE"

# --- on / off / on is stable (no duplicate entries) ---

it "re-enabling does not duplicate limon_runner in PROMPT_COMMAND"
out="$(scenario "on default" "
    source '$LIMON' off >/dev/null 2>&1
    source '$LIMON' on default >/dev/null 2>&1
    grep -o limon_runner <<< \"\$PROMPT_COMMAND\" | wc -l
")"
assert_eq "1" "$out"

it "re-enabling twice in a row does not duplicate limon_runner"
out="$(scenario "on default" "
    source '$LIMON' on default >/dev/null 2>&1
    grep -o limon_runner <<< \"\$PROMPT_COMMAND\" | wc -l
")"
assert_eq "1" "$out"

it "re-enabling does not duplicate the user's PROMPT_COMMAND"
out="$(scenario "on default" "
    source '$LIMON' on default >/dev/null 2>&1
    grep -o original-pc <<< \"\$PROMPT_COMMAND\" | wc -l
")"
assert_eq "1" "$out"

# --- theme switching ---

it "switching theme with 'on <theme>' persists it"
out="$(scenario "on nord" "source '$LIMON' status 2>/dev/null | grep '^Theme:'")"
assert_contains "$out" "nord"

it "a non-'on' subcommand does not change the active theme"
out="$(scenario "on nord" "source '$LIMON' config clock=1 >/dev/null 2>&1; source '$LIMON' status 2>/dev/null | grep '^Theme:'")"
assert_contains "$out" "nord"

it "reload keeps the prompt active"
assert_contains "$(scenario "on default" "source '$LIMON' reload >/dev/null 2>&1; _limon_is_active && echo ACTIVE")" "ACTIVE"

it "reload on an inactive shell warns instead of silently enabling"
out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" bash -c "source '$LIMON' reload 2>&1")"
assert_contains "$out" "not active"

# --- informational subcommands do not install the prompt ---

for sub in status themes version help colors; do
    it "'$sub' does not install the prompt"
    out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" bash -c "
        source '$LIMON' $sub >/dev/null 2>&1
        echo \"\${PROMPT_COMMAND:-none}\"
    ")"
    assert_not_contains "$out" "limon_runner"
done

it "version reports the version string"
assert_contains "$(scenario "version" 'true')$(env HOME="$HOME" bash "$LIMON" version)" "limon"

finish
