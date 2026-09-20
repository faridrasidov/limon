#!/usr/bin/env bash
# Prompt rendering: escape balance, color gating, and segment presence.
#
# Unbalanced \[ \] markers are the classic PS1 bug — bash miscounts the prompt
# width and line editing corrupts the display. These cases cover every theme
# against the option combinations that add or remove segments.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Options below are read by limon.sh once sourced, and '~' is a literal
# display character in expected prompt output, so these do not apply here.
# shellcheck disable=SC2034,SC2088,SC2154

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home
load_limon

REPO="$HOME/work"
make_repo "$REPO"
echo "dirty" >> "$REPO/README"
echo "loose" > "$REPO/untracked"

reset_caches() {
    unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
          __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
          __LIMON_GIT_CACHE_DETACHED __LIMON_STASH_CACHE __LIMON_STASH_CACHE_SEC
}

# render <theme> — run the prompt builder and return the resulting PS1.
render() {
    reset_caches
    LAST_EXIT_CODE="${LAST_EXIT_CODE:-0}"
    main "$1"
    printf '%s' "$PS1"
}

themes=()
while IFS= read -r t; do themes+=("$t"); done < <(_limon_list_themes)

it "found themes to exercise"
assert_ne "0" "${#themes[@]}"

# --- escape balance across the full matrix ---

cd "$REPO" || exit 1
for theme in "${themes[@]}"; do
    for ascii in 0 1; do
        for gitmode in full verbose lite off; do
            LIMON_ASCII="$ascii"
            LIMON_GIT_MODE="$gitmode"
            ps1="$(render "$theme")"
            it "balanced \\[ \\] — theme=$theme ascii=$ascii git=$gitmode"
            if _limon_brackets_balanced "$ps1"; then
                _limon_t_ok
            else
                _limon_t_not_ok "PS1: [$ps1]"
            fi
        done
    done
done
LIMON_ASCII=0
LIMON_GIT_MODE=full

# --- segments appear when enabled ---

it "includes the branch name inside a repo"
assert_contains "$(render default)" "master"

it "omits the git segment when git=off"
LIMON_GIT_MODE=off
assert_not_contains "$(render default)" "master"
LIMON_GIT_MODE=full

it "includes the host segment by default"
assert_contains "$(render default)" '\u@\h'

it "omits the host segment when show_host=0"
LIMON_SHOW_HOST=0
assert_not_contains "$(render default)" '\u@\h'
LIMON_SHOW_HOST=1

it "shows the exit code when show_exit=1 and the last command failed"
LIMON_SHOW_EXIT=1
LAST_EXIT_CODE=127
assert_contains "$(render default)" "127"

it "adds the hint text when exit_hints=1"
LIMON_EXIT_HINTS=1
assert_contains "$(render default)" "not found"
LIMON_EXIT_HINTS=0

it "shows no exit code after a successful command"
LAST_EXIT_CODE=0
assert_not_contains "$(render default)" "127"
LIMON_SHOW_EXIT=0

it "shows the ROOT banner only when show_root=1 and running as root"
LIMON_SHOW_ROOT=1
out="$(render default)"
if [[ "$EUID" -eq 0 ]]; then
    assert_contains "$out" "ROOT"
else
    assert_not_contains "$out" "ROOT"
fi
LIMON_SHOW_ROOT=0

it "shows the env banner when LIMON_ENV is set and env_banner=1"
LIMON_ENV_BANNER=1
LIMON_ENV=prod
assert_contains "$(render default)" "PROD"
LIMON_ENV_BANNER=0
unset LIMON_ENV

it "truncates the path when max_path is small"
LIMON_MAX_PATH=4
assert_contains "$(render default)" "…"
LIMON_MAX_PATH=0

# --- color gating ---
#
# _limon_use_color requires stdout to be a TTY, which it never is under the test
# runner, so the "colors on" path is exercised by overriding that one gate.

it "disables color when LIMON_NO_COLOR=1"
LIMON_NO_COLOR=1
assert_fail _limon_use_color
unset LIMON_NO_COLOR

it "disables color when TERM=dumb"
saved_term="$TERM"
TERM=dumb
assert_fail _limon_use_color
TERM="$saved_term"

it "disables color when stdout is not a TTY"
assert_fail _limon_use_color

it "emits theme color escapes when color is enabled"
_limon_use_color() { return 0; }
assert_contains "$(render default)" '38;5;'

it "still balances \\[ \\] markers with color enabled"
ps1="$(render default)"
if _limon_brackets_balanced "$ps1"; then _limon_t_ok; else _limon_t_not_ok "PS1: [$ps1]"; fi

it "emits no color escapes when color is disabled"
_limon_use_color() { return 1; }
assert_not_contains "$(render default)" '38;5;'
unset -f _limon_use_color
load_limon

# --- ascii mode ---

it "ascii mode leaves no unicode arrow in the prompt"
LIMON_ASCII=1
assert_not_contains "$(render default)" "➜"
LIMON_ASCII=0

it "renders for a theme that does not exist, falling back to defaults"
assert_ne "" "$(render definitely-not-a-theme)"

# --- background jobs ---
#
# The job count is gated behind `jobs -r %%` so the common no-jobs case avoids a
# subshell. These pin both sides of that gate.

it "shows no job counter when there are no background jobs"
assert_not_contains "$(render default)" "[1]"

it "shows the job counter when a background job is running"
sleep 30 &
job_pid=$!
assert_contains "$(render default)" "[1] "

it "counts multiple background jobs"
sleep 30 &
job_pid2=$!
assert_contains "$(render default)" "[2] "

kill "$job_pid" "$job_pid2" 2>/dev/null
wait "$job_pid" "$job_pid2" 2>/dev/null

it "drops the job counter once the jobs finish"
assert_not_contains "$(render default)" "[1] "

finish
