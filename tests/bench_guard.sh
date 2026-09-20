#!/usr/bin/env bash
#
# Prompt render-time regression guard.
#
# The prompt is rendered on every keypress-to-prompt cycle, so its cost is the
# project's headline feature. This measures the mean render time inside a git
# repo and fails if it exceeds a ceiling. The ceiling is loose on purpose — it
# is there to catch a structural regression (per-render theme parsing, a
# reintroduced fork per segment), not to police small deltas on a noisy runner.
#
# Usage: bash tests/bench_guard.sh [iterations] [ceiling_ms]
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -uo pipefail

TESTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$TESTS_DIR/.." && pwd )"

ITERS="${1:-200}"

# Ceiling for the mean render time, in milliseconds.
#
# Steady-state rendering is ~0.3ms; this measurement deliberately forces a fresh
# `git status` on every iteration, which puts a real git process in the loop and
# lands around 3ms on a quiet machine. The ceiling is set well above that so a
# loaded CI runner cannot make it flaky, while still catching a structural
# regression — per-render theme parsing or a reintroduced fork per segment would
# add tens of milliseconds and trip it immediately.
CEILING_MS="${2:-12}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK"
export XDG_CONFIG_HOME="$WORK/.config"
mkdir -p "$XDG_CONFIG_HOME"

# A realistic target: a git repo with staged, unstaged, and untracked changes.
REPO="$WORK/repo"
mkdir -p "$REPO"
git -C "$REPO" init --quiet
git -C "$REPO" config user.email "bench@limon.invalid"
git -C "$REPO" config user.name "Limon Bench"
echo one > "$REPO/a"; git -C "$REPO" add a
git -C "$REPO" commit -qm initial
echo two >> "$REPO/a"
echo three > "$REPO/b"; git -C "$REPO" add b
echo four > "$REPO/c"

if [[ -z "${EPOCHREALTIME:-}" ]]; then
    echo "bench: EPOCHREALTIME unavailable (needs bash 5+); skipping" >&2
    exit 0
fi

mean_us="$(
    LIMON_SOURCE_ONLY=1 source "$REPO_ROOT/limon.sh"
    cd "$REPO" || exit 1
    LAST_EXIT_CODE=0

    # Warm any first-call caches so the measurement reflects steady state.
    main default >/dev/null 2>&1

    t0="${EPOCHREALTIME/./}"
    for (( i = 0; i < ITERS; i++ )); do
        # Clear the 1s git cache so each iteration does the real work a user
        # pays for when moving between directories.
        unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC
        main default
    done
    t1="${EPOCHREALTIME/./}"

    echo $(( (t1 - t0) / ITERS ))
)"

if ! [[ "$mean_us" =~ ^[0-9]+$ ]]; then
    echo "bench: could not measure render time" >&2
    exit 1
fi

printf 'mean render time: %d.%03d ms over %d iterations (ceiling %d ms)\n' \
    $(( mean_us / 1000 )) $(( mean_us % 1000 )) "$ITERS" "$CEILING_MS"

if (( mean_us > CEILING_MS * 1000 )); then
    echo "bench: FAIL — render time exceeds the ${CEILING_MS}ms ceiling" >&2
    echo "bench: the prompt runs on every command; investigate before merging." >&2
    exit 1
fi

echo "bench: OK"
