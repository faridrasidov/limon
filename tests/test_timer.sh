#!/usr/bin/env bash
# Command timer: sub-second resolution, formatting, and threshold parsing.
#
# The timer used to be driven by $SECONDS, so it could only ever report whole
# seconds and broke outright if anything reassigned SECONDS.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034,SC2088,SC2154
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home
load_limon

fmt() { _limon_format_elapsed "$1"; printf '%s' "$__LIMON_ELAPSED_STR"; }

thr() {
    LIMON_TIMER_THRESHOLD="$1"
    unset __LIMON_THRESHOLD_FOR
    _limon_threshold_ms
    printf '%s' "$__LIMON_THRESHOLD_MS"
}

# --- duration formatting ---

it "formats sub-second durations with one decimal"
assert_eq "0.4s" "$(fmt 499)"

it "formats a fractional second the old timer could not express"
assert_eq "1.4s" "$(fmt 1400)"

it "formats a whole second"
assert_eq "2.0s" "$(fmt 2000)"

it "keeps one decimal just under a minute"
assert_eq "59.9s" "$(fmt 59900)"

it "switches to minutes at exactly one minute"
assert_eq "1m 00s" "$(fmt 60000)"

it "zero-pads the seconds in the minutes form"
assert_eq "1m 05s" "$(fmt 65000)"

it "formats multiple minutes"
assert_eq "2m 05s" "$(fmt 125000)"

it "formats durations over an hour"
assert_eq "1h 02m 05s" "$(fmt 3725000)"

it "treats a negative duration as zero"
assert_eq "0.0s" "$(fmt -5)"

# --- threshold parsing ---

it "parses a whole-second threshold"
assert_eq "2000" "$(thr 2)"

it "parses a fractional threshold"
assert_eq "500" "$(thr 0.5)"

it "parses a threshold with two decimals"
assert_eq "1250" "$(thr 1.25)"

it "parses a threshold with a leading dot"
assert_eq "750" "$(thr .75)"

it "accepts a zero threshold"
assert_eq "0" "$(thr 0)"

it "falls back to the default for a non-numeric threshold"
assert_eq "2000" "$(thr abc)"

it "truncates beyond millisecond precision rather than failing"
assert_eq "1234" "$(thr 1.23456)"

# --- config validation ---

limon_cmd() {
    env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color \
        bash "$LIMON_REPO_ROOT/limon.sh" "$@" 2>&1
}

for good in 2 0 0.5 1.25 10 .75; do
    it "accepts timer_threshold=$good"
    assert_not_contains "$(limon_cmd config "timer_threshold=$good")" "limon:"
done

for bad in abc -1 1.2.3 2s ""; do
    it "rejects timer_threshold='$bad'"
    assert_contains "$(limon_cmd config "timer_threshold=$bad")" "limon:"
done

# --- end to end ---

it "measures a real command with sub-second resolution"
out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
    source '$LIMON_REPO_ROOT/limon.sh' on default >/dev/null 2>&1
    LIMON_TIMER_THRESHOLD=0.2
    _limon_preexec 2>/dev/null
    sleep 0.6
    limon_runner
    echo \"ms=\$__LIMON_CMD_ELAPSED_MS\"
")"
ms="${out##*ms=}"
ms="${ms%%$'\n'*}"
if [[ "$ms" =~ ^[0-9]+$ ]] && (( ms >= 500 && ms <= 2000 )); then
    _limon_t_ok
else
    _limon_t_not_ok "expected roughly 600ms for 'sleep 0.6', got: [$ms]"
fi

it "shows the fractional duration in the prompt"
out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
    source '$LIMON_REPO_ROOT/limon.sh' on default >/dev/null 2>&1
    LIMON_TIMER_THRESHOLD=0.2
    _limon_preexec 2>/dev/null
    sleep 0.6
    limon_runner
    echo \"\$PS1\"
")"
assert_contains "$out" "0.6s"

it "shows no timer for a command under the threshold"
out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
    source '$LIMON_REPO_ROOT/limon.sh' on default >/dev/null 2>&1
    LIMON_TIMER_THRESHOLD=5
    _limon_preexec 2>/dev/null
    limon_runner
    echo \"\$PS1\"
")"
assert_not_contains "$out" "s "

finish
