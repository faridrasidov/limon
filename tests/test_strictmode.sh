#!/usr/bin/env bash
# Limon must work in shells that enable strict mode.
#
# A user with `set -u` in their bashrc previously got "unbound variable" errors
# from limon.sh because PS1, PROMPT_COMMAND, VIRTUAL_ENV and friends were read
# without a :- default. These cases pin that down.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034,SC2088,SC2154
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home

LIMON="$LIMON_REPO_ROOT/limon.sh"

# Run limon under `set -u` with a deliberately bare environment: no PS1, no
# PROMPT_COMMAND, no venv/conda/docker variables.
strict() {
    env -u PS1 -u PROMPT_COMMAND -u VIRTUAL_ENV -u CONDA_DEFAULT_ENV \
        -u DOCKER_MACHINE_NAME -u DEFAULT_PS1 -u DEFAULT_PROMPT_COMMAND \
        -u DEFAULT_DEBUG_TRAP -u LAST_EXIT_CODE \
        HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color \
        bash -c "set -u; source '$LIMON' $1 2>&1; $2"
}

it "sources cleanly under set -u with no PS1 or PROMPT_COMMAND"
assert_not_contains "$(strict "on default" 'true')" "unbound variable"

it "renders a prompt under set -u"
out="$(strict "on default" 'echo "PS1=[$PS1]"')"
assert_not_contains "$out" "unbound variable"

it "produces a non-empty prompt under set -u"
assert_contains "$(strict "on default" 'echo "PS1=[$PS1]"')" "PS1=["

it "runs the prompt renderer repeatedly under set -u"
out="$(strict "on default" 'for i in 1 2 3; do limon_runner; done; echo DONE')"
assert_contains "$out" "DONE"

it "handles 'off' under set -u"
assert_not_contains "$(strict "on default" "source '$LIMON' off 2>&1; echo DONE")" "unbound variable"

it "handles 'status' under set -u"
assert_not_contains "$(strict "status" 'true')" "unbound variable"

it "handles 'reload' under set -u"
assert_not_contains "$(strict "on default" "source '$LIMON' reload 2>&1; echo DONE")" "unbound variable"

it "handles 'config' under set -u"
assert_not_contains "$(strict "config clock=1" 'true')" "unbound variable"

it "renders inside a git repo under set -u"
make_repo "$HOME/strictrepo"
out="$(env -u PS1 -u PROMPT_COMMAND -u LAST_EXIT_CODE \
    HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color \
    bash -c "set -u; cd '$HOME/strictrepo'; source '$LIMON' on default 2>&1; limon_runner; echo DONE")"
assert_contains "$out" "DONE"

it "renders under set -u with no unbound-variable error inside a repo"
assert_not_contains "$out" "unbound variable"

finish
