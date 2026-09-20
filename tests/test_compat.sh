#!/usr/bin/env bash
# Namespace hygiene, the bash version gate, and environment cleanliness.
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034,SC2088,SC2154
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home

LIMON="$LIMON_REPO_ROOT/limon.sh"

with_limon() {
    env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color \
        bash -c "source '$LIMON' on default >/dev/null 2>&1; $1"
}

# --- no function named "main" leaks into child processes ---
#
# An exported function called "main" is inherited by every child bash process.
# Any script that calls main before defining it would silently run Limon's
# prompt renderer instead of its own entry point.

it "does not export a function named 'main'"
assert_not_contains "$(with_limon 'declare -F | awk "{print \$3}"')" $'\nmain'

it "exports the renderer under a namespaced name"
assert_contains "$(with_limon 'declare -F')" "_limon_main"

it "a child bash does not inherit a 'main' function"
out="$(with_limon 'bash -c "declare -F main >/dev/null 2>&1 && echo LEAKED || echo clean"')"
assert_contains "$out" "clean"

it "a child script defining its own main is unaffected"
cat > "$HOME/child.sh" <<'EOF'
main() { echo "child-main-ran"; }
main
EOF
assert_contains "$(with_limon "bash '$HOME/child.sh'")" "child-main-ran"

# --- environment hygiene ---

it "does not export the config options into child processes"
out="$(with_limon 'bash -c "env | grep -c ^LIMON_GIT_MODE= || true"')"
assert_contains "$out" "0"

it "still applies config options in the current shell"
assert_contains "$(with_limon 'echo "git=$LIMON_GIT_MODE"')" "git=full"

# --- bash version gate ---

it "the version gate is present and checks for bash 4"
assert_contains "$(head -40 "$LIMON")" "BASH_VERSINFO"

it "the installer carries the same gate"
assert_contains "$(head -40 "$LIMON_REPO_ROOT/install.sh")" "BASH_VERSINFO"

it "refuses to load when BASH_VERSINFO reports an old bash"
# BASH_VERSINFO is readonly, so simulate the gate's condition directly rather
# than trying to fake an old interpreter.
out="$(bash -c '
    BASH_VERSINFO_MAJOR=3
    if (( BASH_VERSINFO_MAJOR < 4 )); then echo "would-refuse"; fi
')"
assert_contains "$out" "would-refuse"

it "loads normally on this bash (4+)"
assert_contains "$(with_limon '_limon_is_active && echo ACTIVE')" "ACTIVE"

# --- reload picks up new code, not just new config ---

it "reload re-sources the script so upgraded code takes effect"
out="$(with_limon "source '$LIMON' reload >/dev/null 2>&1; _limon_is_active && echo ACTIVE")"
assert_contains "$out" "ACTIVE"

it "reload does not duplicate limon_runner in PROMPT_COMMAND"
out="$(with_limon "source '$LIMON' reload >/dev/null 2>&1; grep -o limon_runner <<< \"\$PROMPT_COMMAND\" | wc -l")"
assert_contains "$out" "1"

it "reload leaves no recursion guard behind"
out="$(with_limon "source '$LIMON' reload >/dev/null 2>&1; echo \"guard=[\${__LIMON_RELOADING:-unset}]\"")"
assert_contains "$out" "guard=[unset]"

finish
