#!/usr/bin/env bash
# Installer and uninstaller, end to end and fully offline.
#
# Every case runs against a throwaway HOME, so the real ~/.bashrc and the real
# install are never touched.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034,SC2088,SC2154
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"

INSTALL="$LIMON_REPO_ROOT/install.sh"

# Each case gets its own HOME so state cannot leak between them. Scope is always
# forced to --user: the suite may run as root, where install.sh would otherwise
# default to a system-wide install and write to /etc and /usr/share.
fresh_home() {
    SANDBOX="$(mktemp -d)"
    export SANDBOX
    TARGET="$SANDBOX/.local/share/limon"
    CONFIG="$SANDBOX/.config/limon"
    BASHRC="$SANDBOX/.bashrc"
}

run_install() {
    env HOME="$SANDBOX" XDG_DATA_HOME="$SANDBOX/.local/share" \
        XDG_CONFIG_HOME="$SANDBOX/.config" \
        bash "$INSTALL" --user -y 2>&1
}

run_uninstall() {
    env HOME="$SANDBOX" XDG_DATA_HOME="$SANDBOX/.local/share" \
        XDG_CONFIG_HOME="$SANDBOX/.config" \
        bash "$INSTALL" --user --uninstall "$@" 2>&1
}

# Count matching lines in the rc file, as a single value.
#
# `grep -c` prints "0" *and* exits 1 when nothing matches, so a naive
# `|| echo 0` fallback emits two zeros.
count_in_bashrc() {
    local n
    n="$(grep -c "$1" "$BASHRC" 2>/dev/null || true)"
    printf '%s' "${n:-0}"
}

# How many times the managed block opens in the rc file.
block_count() { count_in_bashrc '^# >>> limon >>>'; }

# --- install -----------------------------------------------------------------

fresh_home
install_out="$(run_install)"

it "install exits successfully"
assert_contains "$install_out" "Limon is installed"

it "install puts limon.sh in the target directory"
assert_ok test -f "$TARGET/limon.sh"

it "install puts the completion script in the target directory"
assert_ok test -f "$TARGET/hint-limon.sh"

it "install copies the themes"
assert_ok test -f "$TARGET/themes/default.theme"

it "install adds the managed block to .bashrc"
assert_eq "1" "$(block_count)"

it "install wires up the limon alias"
assert_contains "$(cat "$BASHRC")" "alias limon="

it "install enables the prompt on startup"
assert_contains "$(cat "$BASHRC")" "limon.sh on"

it "install tells the user what to do next"
assert_contains "$install_out" "source ~/.bashrc"

# --- idempotence -------------------------------------------------------------
#
# install.sh strips any previous block before appending a new one. Nothing
# proved that until now, and a duplicated block means Limon is initialised twice
# on every new shell.

it "installing twice does not duplicate the managed block"
run_install >/dev/null
assert_eq "1" "$(block_count)"

it "installing three times still leaves exactly one block"
run_install >/dev/null
assert_eq "1" "$(block_count)"

it "installing twice does not duplicate the alias"
assert_eq "1" "$(count_in_bashrc '^alias limon=')"

# --- the installed copy actually works ---------------------------------------

# NOTE: the markers here must not be substrings of one another. "INACTIVE"
# contains "ACTIVE", so asserting on those two made this check pass either way.
it "a shell sourcing the generated .bashrc ends up with Limon active"
out="$(env HOME="$SANDBOX" XDG_DATA_HOME="$SANDBOX/.local/share" \
    XDG_CONFIG_HOME="$SANDBOX/.config" TERM=xterm-256color \
    bash -c "source '$BASHRC' >/dev/null 2>&1; case \"\$PROMPT_COMMAND\" in
        *limon_runner*) echo LIMON-ON ;;
        *) echo LIMON-OFF ;;
    esac")"
assert_eq "LIMON-ON" "$out"

it "the startup line does not depend on alias expansion"
# Aliases are not expanded in non-interactive shells, so an rc block that
# enables the prompt via the alias silently does nothing in those contexts.
assert_contains "$(cat "$BASHRC")" "limon.sh on"

it "the rc block still defines the limon alias for interactive use"
assert_contains "$(cat "$BASHRC")" "alias limon="

it "the installed copy reports the current version"
out="$(env HOME="$SANDBOX" XDG_CONFIG_HOME="$SANDBOX/.config" \
    bash "$TARGET/limon.sh" version 2>&1)"
assert_contains "$out" "$(grep -m1 '^LIMON_VERSION=' "$LIMON_REPO_ROOT/limon.sh" | cut -d'"' -f2)"

# --- uninstall ---------------------------------------------------------------
#
# Two bugs used to hide here. `grep -v` exits 1 when it selects no lines, which
# under `set -euo pipefail` aborted the uninstall before anything was removed —
# triggered whenever the rc file held nothing but the Limon block. And the
# removal deleted $TARGET_DIR (derived from the scope flag) rather than the
# directory it had just found, so a user install was reported as removed while
# a different path was deleted.

fresh_home
run_install >/dev/null
mkdir -p "$CONFIG" && echo "default" > "$CONFIG/limon.conf"

uninstall_out="$(run_uninstall --keep-config)"

it "uninstall runs to completion"
assert_contains "$uninstall_out" "Limon has been removed"

it "uninstall removes the install directory it found"
assert_fail test -d "$TARGET"

it "uninstall strips the managed block from .bashrc"
assert_eq "0" "$(block_count)"

it "uninstall leaves no limon lines behind in .bashrc"
assert_eq "0" "$(count_in_bashrc limon)"

it "--keep-config keeps the config directory"
assert_ok test -d "$CONFIG"

# --- uninstall with an rc file that has other content ------------------------

fresh_home
mkdir -p "$SANDBOX"
printf '%s\n' "export EDITOR=vim" "alias ll='ls -la'" > "$BASHRC"
run_install >/dev/null
run_uninstall --keep-config >/dev/null

it "uninstall preserves unrelated .bashrc content"
assert_contains "$(cat "$BASHRC")" "export EDITOR=vim"

it "uninstall preserves unrelated aliases"
assert_contains "$(cat "$BASHRC")" "alias ll="

it "uninstall still removes the limon block from a populated .bashrc"
assert_eq "0" "$(block_count)"

# --- purge -------------------------------------------------------------------

fresh_home
run_install >/dev/null
mkdir -p "$CONFIG" && echo "default" > "$CONFIG/limon.conf"
run_uninstall --purge >/dev/null

it "--purge removes the config directory too"
assert_fail test -d "$CONFIG"

# --- uninstalling when nothing is installed ----------------------------------

fresh_home
it "uninstall on a clean system does not fail"
out="$(run_uninstall --keep-config)"
assert_contains "$out" "Limon has been removed"

finish
