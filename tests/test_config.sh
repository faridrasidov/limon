#!/usr/bin/env bash
# Config load/write round-trip and `limon config` validation.
# SPDX-License-Identifier: GPL-3.0-or-later

# Options below are read by limon.sh once sourced, and '~' is a literal
# display character in expected prompt output, so these do not apply here.
# shellcheck disable=SC2034,SC2088,SC2154

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home
load_limon

# Run a subcommand the way a user would, in its own process.
limon_cmd() {
    env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color \
        bash "$LIMON_REPO_ROOT/limon.sh" "$@" 2>&1
}

# --- defaults ---

rm -f "$LIMON_CONF"
_limon_load_config

it "defaults to the 'default' theme with no config file"
assert_eq "default" "$saved_theme"

it "defaults git mode to full"
assert_eq "full" "$LIMON_GIT_MODE"

it "enables ghost autosuggestions by default"
assert_eq "1:100:auto" "$LIMON_AUTOSUGGEST:$LIMON_AUTOSUGGEST_DELAY:$LIMON_AUTOSUGGEST_COLOR"

it "disables syntax highlighting and fzf key bindings by default"
assert_eq "0:0" "$LIMON_HIGHLIGHT:$LIMON_FZF"

it "emits no flags when every option is at its default"
assert_eq "" "$(_limon_conf_flags)"

# --- write / load round-trip ---

LIMON_GIT_MODE="verbose"
LIMON_ASCII="1"
LIMON_MAX_PATH="40"
LIMON_HOST_COLOR="auto"
LIMON_AUTOSUGGEST_DELAY="250"
LIMON_AUTOSUGGEST_COLOR="244"
LIMON_HIGHLIGHT="1"
LIMON_FZF="1"
mapfile -t flags < <(_limon_conf_flags)
_limon_write_config "nord" "${flags[@]}"

it "writes the theme name first"
assert_contains "$(cat "$LIMON_CONF")" "nord"

# Reload into a clean slate and confirm every value survived.
_limon_load_config

it "round-trips the theme name"
assert_eq "nord" "$saved_theme"
it "round-trips git mode"
assert_eq "verbose" "$LIMON_GIT_MODE"
it "round-trips ascii"
assert_eq "1" "$LIMON_ASCII"
it "round-trips max_path"
assert_eq "40" "$LIMON_MAX_PATH"
it "round-trips host_color"
assert_eq "auto" "$LIMON_HOST_COLOR"
it "round-trips autosuggestion settings"
assert_eq "250:244" "$LIMON_AUTOSUGGEST_DELAY:$LIMON_AUTOSUGGEST_COLOR"
it "round-trips highlight and fzf"
assert_eq "1:1" "$LIMON_HIGHLIGHT:$LIMON_FZF"

it "resets options absent from the config back to defaults"
_limon_write_config "default"
_limon_load_config
assert_eq "full" "$LIMON_GIT_MODE"
it "resets highlight and fzf back to defaults too"
assert_eq "0:0" "$LIMON_HIGHLIGHT:$LIMON_FZF"

# --- validation of enumerated options ---

for pair in git=full git=lite git=verbose git=off \
            autoupdate=off autoupdate=notify autoupdate=on \
            channel=stable channel=beta channel=dev \
            ascii=0 ascii=1 env_banner=1 show_root=1 show_sudo=0 \
            k8s=1 cloud=1 show_exit=1 exit_hints=1 clock=1 metrics=1 \
            show_host=0 show_host=1 show_ssh=0 show_ssh=1 \
            autosuggest=0 autosuggest=1 autosuggest_delay=0 autosuggest_delay=2000 \
            autosuggest_color=auto autosuggest_color=245 \
            highlight=0 highlight=1 fzf=0 fzf=1 \
            host_color=auto host_color=off host_color=120 \
            max_path=0 max_path=40; do
    it "accepts '$pair'"
    out="$(limon_cmd config "$pair")"
    assert_not_contains "$out" "limon:"
done

for pair in git=bogus autoupdate=maybe channel=nightly ascii=2 \
            max_path=-1 max_path=abc host_color=999 host_color=purple \
            env_banner=2 show_root=yes show_host=yes show_ssh=2 metrics=on \
            autosuggest=yes autosuggest_delay=-1 autosuggest_delay=2001 \
            autosuggest_color=purple autosuggest_color=256 \
            highlight=2 highlight=yes fzf=2 fzf=yes; do
    it "rejects '$pair'"
    out="$(limon_cmd config "$pair")"
    assert_contains "$out" "limon:"
done

it "rejects an entirely unknown key"
assert_contains "$(limon_cmd config nonsense=1)" "unknown config option"

it "a rejected value does not get written to the config file"
limon_cmd config git=full >/dev/null
limon_cmd config git=bogus >/dev/null
_limon_load_config
assert_eq "full" "$LIMON_GIT_MODE"

it "bare 'limon config' prints current values without changing them"
out="$(limon_cmd config)"
assert_contains "$out" "Current:"

finish
