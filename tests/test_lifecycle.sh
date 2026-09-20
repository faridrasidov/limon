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
assert_contains "$(scenario "on default" 'declare -p PROMPT_COMMAND')" "original-pc"

it "replaces PS1"
assert_not_contains "$(scenario "on default" 'echo "$PS1"')" "original-ps1"

it "records the original PS1 for restoration"
assert_contains "$(scenario "on default" 'echo "$DEFAULT_PS1"')" "original-ps1"

it "installs trap-free PS0 command timing"
assert_contains "$(scenario "on default" 'printf "%s" "$PS0"')" "__LIMON_CMD_START"

it "does not install a DEBUG trap"
assert_not_contains "$(scenario "on default" 'trap -p DEBUG')" "_limon_preexec"

it "reports itself active"
assert_contains "$(scenario "on default" '_limon_is_active && echo ACTIVE')" "ACTIVE"

# --- limon off restores the shell ---

it "off restores the original PS1"
assert_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; echo \"\$PS1\"")" "original-ps1"

it "off removes limon_runner from PROMPT_COMMAND"
assert_not_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; echo \"\$PROMPT_COMMAND\"")" "limon_runner"

it "off restores the user's original PROMPT_COMMAND"
assert_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; echo \"\$PROMPT_COMMAND\"")" "original-pc"

it "off removes only Limon's PS0 prefix"
out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
    PS0='user-ps0'
    source '$LIMON' on default >/dev/null 2>&1
    source '$LIMON' off >/dev/null 2>&1
    printf '%s' \"\$PS0\"
")"
assert_eq "user-ps0" "$out"

it "off preserves PROMPT_COMMAND changes made while Limon is active"
out="$(scenario "on default" "
    if [[ \"\$(declare -p PROMPT_COMMAND 2>/dev/null)\" == 'declare -a'* ]]; then
        PROMPT_COMMAND+=('echo added-later')
    else
        PROMPT_COMMAND=\"\$PROMPT_COMMAND; echo added-later\"
    fi
    source '$LIMON' off >/dev/null 2>&1
    declare -p PROMPT_COMMAND
")"
assert_contains "$out" "added-later"

it "_limon_preexec is inert once Limon is off"
out="$(scenario "on default" "
    source '$LIMON' off >/dev/null 2>&1
    __LIMON_CMD_ACTIVE=0
    _limon_preexec
    echo \"active=\${__LIMON_CMD_ACTIVE:-0}\"
")"
assert_contains "$out" "active=0"

if (( BASH_VERSINFO[0] > 5 || BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1 )); then
    it "preserves PROMPT_COMMAND arrays on bash 5.1+"
    out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
        PS1='original> '
        PROMPT_COMMAND=('echo first' 'echo second')
        source '$LIMON' on default >/dev/null 2>&1
        declare -p PROMPT_COMMAND
    ")"
    assert_contains "$out" 'declare -a PROMPT_COMMAND=([0]="limon_runner" [1]="echo first" [2]="echo second")'

    it "off removes its array element without erasing other hooks"
    out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
        PS1='original> '
        PROMPT_COMMAND=('echo first' 'echo second')
        source '$LIMON' on default >/dev/null 2>&1
        PROMPT_COMMAND+=('echo third')
        source '$LIMON' off >/dev/null 2>&1
        declare -p PROMPT_COMMAND
    ")"
    assert_contains "$out" '[2]="echo third"'
fi

it "off reports itself inactive"
assert_contains "$(scenario "on default" "source '$LIMON' off >/dev/null 2>&1; _limon_is_active || echo INACTIVE")" "INACTIVE"

# --- on / off / on is stable (no duplicate entries) ---

it "re-enabling does not duplicate limon_runner in PROMPT_COMMAND"
out="$(scenario "on default" "
    source '$LIMON' off >/dev/null 2>&1
    source '$LIMON' on default >/dev/null 2>&1
    declare -p PROMPT_COMMAND | grep -o limon_runner | wc -l
")"
assert_eq "1" "$out"

it "re-enabling twice in a row does not duplicate limon_runner"
out="$(scenario "on default" "
    source '$LIMON' on default >/dev/null 2>&1
    declare -p PROMPT_COMMAND | grep -o limon_runner | wc -l
")"
assert_eq "1" "$out"

it "re-enabling does not duplicate the user's PROMPT_COMMAND"
out="$(scenario "on default" "
    source '$LIMON' on default >/dev/null 2>&1
    declare -p PROMPT_COMMAND | grep -o original-pc | wc -l
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
