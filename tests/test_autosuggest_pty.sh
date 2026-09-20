#!/usr/bin/env bash
# Real PTY smoke test for rendering and accepting a history ghost suggestion.
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034,SC2088,SC2154
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home

it "renders and accepts a history ghost suggestion in an interactive terminal"
if ! command -v expect >/dev/null 2>&1; then
    skip "expect is not installed — install it to run this test locally (CI always runs it)"
else
    if HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
        expect "$LIMON_TEST_DIR/autosuggest.exp" "$LIMON_REPO_ROOT/limon.sh"; then
        _limon_t_ok
    else
        _limon_t_not_ok "interactive autosuggestion smoke test failed"
    fi
fi

finish
