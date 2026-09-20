#!/usr/bin/env bash
#
# Limon test runner — pure bash, no external dependencies.
# Copyright (C) 2026 Farid Rasidov
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Usage:
#   bash tests/run.sh              # run every tests/test_*.sh
#   bash tests/run.sh path         # run only files whose name matches 'path'

set -uo pipefail

TESTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FILTER="${1:-}"

if ! command -v git >/dev/null 2>&1; then
    echo "tests: git is required for the git fixture tests" >&2
    exit 1
fi

total_files=0
failed_files=0
failed_names=()

for file in "$TESTS_DIR"/test_*.sh; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file")"
    if [[ -n "$FILTER" && "$name" != *"$FILTER"* ]]; then
        continue
    fi

    total_files=$((total_files + 1))
    printf '\n%s\n' "$name"

    # Each file runs in its own bash process with a clean environment, so one
    # file's globals, traps, or exported config can never leak into the next.
    if ! env -u LIMON_SOURCE_ONLY -u PROMPT_COMMAND -u PS1 \
         TERM=xterm-256color bash "$file"; then
        failed_files=$((failed_files + 1))
        failed_names+=("$name")
    fi
done

echo
if [[ $total_files -eq 0 ]]; then
    echo "tests: no test files matched${FILTER:+ '$FILTER'}" >&2
    exit 1
fi

if [[ $failed_files -eq 0 ]]; then
    printf '\033[32mAll %d test file(s) passed.\033[0m\n' "$total_files"
    exit 0
fi

printf '\033[31m%d of %d test file(s) failed:\033[0m\n' "$failed_files" "$total_files"
printf '  %s\n' "${failed_names[@]}"
exit 1
