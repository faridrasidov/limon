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

fmt() { _limon_format_elapsed "$1" "${2:-1}"; printf '%s' "$__LIMON_ELAPSED_STR"; }

# Sub-second timing needs a fork-free high-resolution clock. Bash 4 has none,
# and running `date` before every command would cost more than the extra
# precision is worth, so those shells keep whole-second timing. Tests that
# assert tenths have to be gated on that.
if [[ -n "${EPOCHREALTIME:-}" ]]; then
    HIRES=1
else
    HIRES=0
fi

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

# --- whole-second formatting (the bash 4 fallback path) ---
#
# Printing "1.0s" when the measurement only has whole-second resolution would
# advertise a precision the number does not have.

it "drops the decimal when resolution is whole seconds"
assert_eq "1s" "$(fmt 1000 0)"

it "does not invent tenths from a whole-second measurement"
assert_eq "0s" "$(fmt 0 0)"

it "still uses the minutes form without hi-res resolution"
assert_eq "2m 05s" "$(fmt 125000 0)"

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

# time_a_command <extra-setup> — runs `sleep 0.6` under the real preexec/runner
# pair and echoes the measured milliseconds and the resulting PS1.
time_a_command() {
    env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
        ${1:-}
        source '$LIMON_REPO_ROOT/limon.sh' on default >/dev/null 2>&1
        LIMON_TIMER_THRESHOLD=0.2
        _limon_preexec 2>/dev/null
        sleep 0.6
        limon_runner
        echo \"ms=\$__LIMON_CMD_ELAPSED_MS hires=\$__LIMON_TIMER_HIRES ps1=\$PS1\"
    "
}

if (( HIRES )); then
    it "measures a real command with sub-second resolution"
    out="$(time_a_command)"
    ms="${out##*ms=}"; ms="${ms%% *}"
    if [[ "$ms" =~ ^[0-9]+$ ]] && (( ms >= 500 && ms <= 2000 )); then
        _limon_t_ok
    else
        _limon_t_not_ok "expected roughly 600ms for 'sleep 0.6', got: [$ms]" "full: $out"
    fi

    it "shows the fractional duration in the prompt"
    assert_contains "$(time_a_command)" "0.6s"

    it "reports the measurement as high-resolution"
    assert_contains "$(time_a_command)" "hires=1"
else
    it "skips sub-second assertions without a high-resolution clock"
    _limon_t_ok
fi

# The whole-second fallback must work on every bash, so exercise it here even
# when a high-resolution clock is available, by taking EPOCHREALTIME away.
it "falls back to whole-second timing with no high-resolution clock"
assert_contains "$(time_a_command 'unset EPOCHREALTIME')" "hires=0"

it "shows no misleading decimal on the whole-second path"
out="$(time_a_command 'unset EPOCHREALTIME')"
ps1="${out##*ps1=}"
# Whole-second timing reports either 0s (command did not cross a second
# boundary, so no timer at all) or "1s" — never "1.0s".
assert_not_contains "$ps1" ".0s"

it "shows no timer for a command under the threshold"
out="$(env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color bash -c "
    source '$LIMON_REPO_ROOT/limon.sh' on default >/dev/null 2>&1
    LIMON_TIMER_THRESHOLD=5
    _limon_preexec 2>/dev/null
    limon_runner
    echo \"\$PS1\"
")"
# Match the timer's actual shape (a digit followed by "s") rather than the
# bare substring "s ", which a branch or directory name could contain.
if [[ "$out" =~ [0-9]s ]]; then
    _limon_t_not_ok "expected no timer below the threshold" "PS1: [$out]"
else
    _limon_t_ok
fi

finish
