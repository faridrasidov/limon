#!/usr/bin/env bash
# Autosuggestion configuration, vendoring, and ble.sh integration helpers.
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034,SC2088,SC2154
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home
load_limon

BLE="$LIMON_REPO_ROOT/vendor/blesh/ble.sh"
META="$LIMON_REPO_ROOT/vendor/blesh/UPSTREAM.md"

it "bundles the architecture-independent ble.sh runtime"
assert_ok test -s "$BLE"

it "bundled ble.sh reports the pinned upstream revision"
assert_contains "$(bash "$BLE" --version 2>&1)" "0.4.0-nightly+d81fd54"

it "records the full immutable upstream commit"
assert_contains "$(cat "$META")" "d81fd54feb0d996fdff20dca27eaf0201f7015cc"

# Exercise Limon's public ble.sh configuration contract without attaching a
# real line editor to this non-interactive test process.
bleopt_complete_auto_complete=old-auto
bleopt_complete_auto_history=old-history
bleopt_complete_auto_delay=321
bleopt_highlight_syntax=old-syntax
bleopt_highlight_filename=old-filename
bleopt_highlight_variable=old-variable
bleopt_complete_ambiguous=old-ambiguous
bleopt_complete_menu_complete=old-menu
bleopt_complete_menu_filter=old-filter
bleopt_prompt_eol_mark=old-eol
bleopt_exec_errexit_mark=old-exit
FAKE_FACE="fg=238,bg=254"
FAKE_HOOKS=""

bleopt() {
    local spec name value
    for spec in "$@"; do
        [[ "$spec" == *=* ]] || continue
        name="${spec%%=*}"
        value="${spec#*=}"
        printf -v "bleopt_$name" '%s' "$value"
    done
}

blehook() {
    FAKE_HOOKS+=" $*"
}

FAKE_BINDS=""
ble-bind() {
    FAKE_BINDS+="|$*"
}

ble-face() {
    if [[ "${1:-}" == "--color=never" ]]; then
        echo "ble-face auto_complete=$FAKE_FACE"
    elif [[ "${1:-}" == auto_complete=* ]]; then
        FAKE_FACE="${1#*=}"
    fi
}

LIMON_AUTOSUGGEST=1
LIMON_AUTOSUGGEST_DELAY=125
LIMON_AUTOSUGGEST_COLOR=245
_limon_ble_configure

it "enables history and programmable-completion suggestions"
assert_eq "1:1" "$bleopt_complete_auto_complete:$bleopt_complete_auto_history"

it "applies the configured autosuggestion delay and color"
assert_eq "125:fg=245" "$bleopt_complete_auto_delay:$FAKE_FACE"

it "turns off ble.sh visual features outside ghost suggestions"
assert_eq "::" "$bleopt_highlight_syntax:$bleopt_highlight_filename:$bleopt_highlight_variable"

it "registers timer and prompt callbacks on public ble.sh hooks"
assert_contains "$FAKE_HOOKS" "PREEXEC!=_limon_preexec PRECMD!=limon_runner"

_limon_ble_restore

it "restores an existing ble.sh configuration on detach"
assert_eq "old-auto:321:old-syntax:fg=238,bg=254" \
    "$bleopt_complete_auto_complete:$bleopt_complete_auto_delay:$bleopt_highlight_syntax:$FAKE_FACE"

it "does not rebind keys in a user-owned ble.sh"
assert_eq "" "$FAKE_BINDS"

__LIMON_BLE_OWNED=1
_limon_ble_configure

it "binds Alt+Backspace to kill-backward-cword in the bundled editor"
assert_contains "$FAKE_BINDS" "-m emacs -f M-DEL kill-backward-cword"
assert_contains "$FAKE_BINDS" "-m emacs -f M-BS kill-backward-cword"
assert_contains "$FAKE_BINDS" "-m vi_imap -f M-DEL kill-backward-cword"

_limon_ble_restore

it "leaves a bundled editor resident but inert when Limon turns off"
assert_eq "::" "$bleopt_complete_auto_complete:$bleopt_highlight_syntax:$bleopt_prompt_eol_mark"

finish
