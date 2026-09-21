#!/usr/bin/env bash
#
# limon - Optimized Bash Prompt
# Copyright (C) 2026 Farid Rasidov
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SPDX-License-Identifier: GPL-3.0-or-later
# See the LICENSE file for the full text.

# limon - Optimized Bash Prompt
# Features: 256-Color ANSI Support, Color Picker, Silent Default, Modular Themes

LIMON_VERSION="1.2.1"

# --- 0. Bash version gate ---
#
# Limon needs bash 4.4+ (including PS0 for trap-free native timing). macOS still ships bash 3.2 as
# /bin/bash, so without this check those users hit a confusing syntax or
# "command not found" error somewhere deep in the script instead of a clear
# message. Fail here, before anything touches PS1 or PROMPT_COMMAND.
if [[ -z "${BASH_VERSINFO[0]:-}" ]] || \
   (( BASH_VERSINFO[0] < 4 || BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4 )); then
    echo "limon: requires bash 4.4 or newer (found ${BASH_VERSION:-unknown})." >&2
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        echo "limon: macOS ships bash 3.2 as /bin/bash. Install a newer bash with:" >&2
        echo "limon:   brew install bash" >&2
        echo "limon: then make it your login shell, or run Limon under that bash." >&2
    fi
    return 1 2>/dev/null || exit 1
fi

# --- 1. Self-Healing & Safety ---
if [ -z "${DEFAULT_PS1:-}" ]; then
    DEFAULT_PS1="${PS1:-}"
    export DEFAULT_PS1
fi

# --- 2. Path & Config Setup ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    LIMON_CONF_DIR="$XDG_CONFIG_HOME/limon"
else
    LIMON_CONF_DIR="$HOME/.config/limon"
fi
LIMON_CONF="$LIMON_CONF_DIR/limon.conf"
mkdir -p "$LIMON_CONF_DIR"

LIMON_TIMER_THRESHOLD=2
LIMON_GIT_MODE=full
LIMON_SHOW_HOST=1
LIMON_SHOW_SSH=0
LIMON_AUTOUPDATE=off
LIMON_CHANNEL=stable
LIMON_ASCII=0
LIMON_MAX_PATH=0
LIMON_HOST_COLOR=off
LIMON_ENV_BANNER=0
LIMON_SHOW_ROOT=0
LIMON_SHOW_SUDO=1
LIMON_K8S=0
LIMON_CLOUD=0
LIMON_SHOW_EXIT=0
LIMON_EXIT_HINTS=0
LIMON_SHOW_CLOCK=0
LIMON_METRICS=0
LIMON_AUTOSUGGEST=1
LIMON_AUTOSUGGEST_DELAY=100
LIMON_AUTOSUGGEST_COLOR=auto

# The one-line install command, shown wherever a non-git install needs updating.
LIMON_INSTALL_ONELINER='curl -fsSL https://raw.githubusercontent.com/faridrasidov/limon/master/get-limon.sh | bash'

LIMON_UPDATE_STAMP="$LIMON_CONF_DIR/.last_update_check"
LIMON_UPDATE_FLAG="$LIMON_CONF_DIR/.update_available"
LIMON_UPDATE_INTERVAL=86400

_limon_theme_dirs() {
    echo "$LIMON_CONF_DIR/themes"
    echo "/usr/share/limon/themes"
    echo "$SCRIPT_DIR/themes"
}

_limon_theme_paths() {
    local theme_name="$1"
    local dir
    while IFS= read -r dir; do
        echo "$dir/${theme_name}.theme"
    done < <(_limon_theme_dirs)
}

_limon_resolve_theme_file() {
    local theme_name="$1"
    local path
    while IFS= read -r path; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done < <(_limon_theme_paths "$theme_name")
    return 1
}

_limon_theme_exists() {
    _limon_resolve_theme_file "$1" >/dev/null
}

_limon_list_themes() {
    local dir file name seen=""
    while IFS= read -r dir; do
        [[ -d "$dir" ]] || continue
        for file in "$dir"/*.theme; do
            [[ -f "$file" ]] || continue
            name="${file##*/}"
            name="${name%.theme}"
            [[ " $seen " == *" $name "* ]] && continue
            seen+=" $name"
            echo "$name"
        done
    done < <(_limon_theme_dirs)
}

_limon_load_config() {
    saved_theme="default"
    LIMON_TIMER_THRESHOLD=2
    LIMON_GIT_MODE=full
    LIMON_SHOW_HOST=1
    LIMON_SHOW_SSH=0
    LIMON_AUTOUPDATE=off
    LIMON_CHANNEL=stable
    LIMON_ASCII=0
    LIMON_MAX_PATH=0
    LIMON_HOST_COLOR=off
    LIMON_ENV_BANNER=0
    LIMON_SHOW_ROOT=0
    LIMON_SHOW_SUDO=1
    LIMON_K8S=0
    LIMON_CLOUD=0
    LIMON_SHOW_EXIT=0
    LIMON_EXIT_HINTS=0
    LIMON_SHOW_CLOCK=0
    LIMON_METRICS=0
    LIMON_AUTOSUGGEST=1
    LIMON_AUTOSUGGEST_DELAY=100
    LIMON_AUTOSUGGEST_COLOR=auto

    if [[ -f "$LIMON_CONF" ]]; then
        read -r -a conf_parts < "$LIMON_CONF"
        for part in "${conf_parts[@]}"; do
            case "$part" in
                -timer_threshold=*) LIMON_TIMER_THRESHOLD="${part#*=}" ;;
                -git=*) LIMON_GIT_MODE="${part#*=}" ;;
                -show_host=*) LIMON_SHOW_HOST="${part#*=}" ;;
                -show_ssh=*) LIMON_SHOW_SSH="${part#*=}" ;;
                -autoupdate=*) LIMON_AUTOUPDATE="${part#*=}" ;;
                -channel=*) LIMON_CHANNEL="${part#*=}" ;;
                -ascii=*) LIMON_ASCII="${part#*=}" ;;
                -max_path=*) LIMON_MAX_PATH="${part#*=}" ;;
                -host_color=*) LIMON_HOST_COLOR="${part#*=}" ;;
                -env_banner=*) LIMON_ENV_BANNER="${part#*=}" ;;
                -show_root=*) LIMON_SHOW_ROOT="${part#*=}" ;;
                -show_sudo=*) LIMON_SHOW_SUDO="${part#*=}" ;;
                -k8s=*) LIMON_K8S="${part#*=}" ;;
                -cloud=*) LIMON_CLOUD="${part#*=}" ;;
                -show_exit=*) LIMON_SHOW_EXIT="${part#*=}" ;;
                -exit_hints=*) LIMON_EXIT_HINTS="${part#*=}" ;;
                -clock=*) LIMON_SHOW_CLOCK="${part#*=}" ;;
                -metrics=*) LIMON_METRICS="${part#*=}" ;;
                -autosuggest=*) LIMON_AUTOSUGGEST="${part#*=}" ;;
                -autosuggest_delay=*) LIMON_AUTOSUGGEST_DELAY="${part#*=}" ;;
                -autosuggest_color=*) LIMON_AUTOSUGGEST_COLOR="${part#*=}" ;;
                -*) ;;
                *) saved_theme="$part" ;;
            esac
        done
    fi
}

_limon_write_config() {
    local theme_name="$1"
    shift
    local flags=("$@")
    {
        printf '%s' "$theme_name"
        local flag
        for flag in "${flags[@]}"; do
            printf ' %s' "$flag"
        done
        printf '\n'
    } > "$LIMON_CONF"
}

_limon_conf_flags() {
    local flags=()
    [[ "$LIMON_TIMER_THRESHOLD" != "2" ]] && flags+=("-timer_threshold=$LIMON_TIMER_THRESHOLD")
    [[ "$LIMON_GIT_MODE" != "full" ]] && flags+=("-git=$LIMON_GIT_MODE")
    [[ "$LIMON_SHOW_HOST" != "1" ]] && flags+=("-show_host=$LIMON_SHOW_HOST")
    [[ "$LIMON_SHOW_SSH" != "0" ]] && flags+=("-show_ssh=$LIMON_SHOW_SSH")
    [[ "$LIMON_AUTOUPDATE" != "off" ]] && flags+=("-autoupdate=$LIMON_AUTOUPDATE")
    [[ "$LIMON_CHANNEL" != "stable" ]] && flags+=("-channel=$LIMON_CHANNEL")
    [[ "$LIMON_ASCII" != "0" ]] && flags+=("-ascii=$LIMON_ASCII")
    [[ "$LIMON_MAX_PATH" != "0" ]] && flags+=("-max_path=$LIMON_MAX_PATH")
    [[ "$LIMON_HOST_COLOR" != "off" ]] && flags+=("-host_color=$LIMON_HOST_COLOR")
    [[ "$LIMON_ENV_BANNER" != "0" ]] && flags+=("-env_banner=$LIMON_ENV_BANNER")
    [[ "$LIMON_SHOW_ROOT" != "0" ]] && flags+=("-show_root=$LIMON_SHOW_ROOT")
    [[ "$LIMON_SHOW_SUDO" != "1" ]] && flags+=("-show_sudo=$LIMON_SHOW_SUDO")
    [[ "$LIMON_K8S" != "0" ]] && flags+=("-k8s=$LIMON_K8S")
    [[ "$LIMON_CLOUD" != "0" ]] && flags+=("-cloud=$LIMON_CLOUD")
    [[ "$LIMON_SHOW_EXIT" != "0" ]] && flags+=("-show_exit=$LIMON_SHOW_EXIT")
    [[ "$LIMON_EXIT_HINTS" != "0" ]] && flags+=("-exit_hints=$LIMON_EXIT_HINTS")
    [[ "$LIMON_SHOW_CLOCK" != "0" ]] && flags+=("-clock=$LIMON_SHOW_CLOCK")
    [[ "$LIMON_METRICS" != "0" ]] && flags+=("-metrics=$LIMON_METRICS")
    [[ "$LIMON_AUTOSUGGEST" != "1" ]] && flags+=("-autosuggest=$LIMON_AUTOSUGGEST")
    [[ "$LIMON_AUTOSUGGEST_DELAY" != "100" ]] && flags+=("-autosuggest_delay=$LIMON_AUTOSUGGEST_DELAY")
    [[ "$LIMON_AUTOSUGGEST_COLOR" != "auto" ]] && flags+=("-autosuggest_color=$LIMON_AUTOSUGGEST_COLOR")
    printf '%s\n' "${flags[@]}"
}

_limon_is_active() {
    [[ "${__LIMON_ACTIVE:-0}" == "1" ]]
}

_limon_preexec() {
    _limon_is_active || return 0
    [[ "${__LIMON_IN_PROMPT:-0}" == "1" ]] && return 0
    [[ "${BASH_COMMAND:-}" == "limon_runner"* ]] && return 0
    [[ "${BASH_COMMAND:-}" == "__LIMON_IN_PROMPT="* ]] && return 0
    [[ "${BASH_COMMAND:-}" == "_limon_preexec"* ]] && return 0

    if [[ "${__LIMON_CMD_ACTIVE:-0}" != "1" ]]; then
        # $EPOCHREALTIME is a bash 5 builtin variable, so reading it costs
        # nothing. On bash 4 there is no fork-free high-resolution clock, and
        # this runs before every command, so fall back to whole seconds rather
        # than forking `date` on each one.
        if [[ -n "${EPOCHREALTIME:-}" ]]; then
            _limon_clock_us
            __LIMON_CMD_START_US="$__LIMON_T"
        else
            __LIMON_CMD_START_US=""
        fi
        __LIMON_CMD_START=$SECONDS
        __LIMON_CMD_ACTIVE=1
    fi
}

_limon_bash_has_prompt_array() {
    (( BASH_VERSINFO[0] > 5 || BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1 ))
}

_limon_prompt_hook_add() {
    _limon_prompt_hook_remove

    if _limon_bash_has_prompt_array; then
        local declaration item
        local -a previous=()
        declaration="$(declare -p PROMPT_COMMAND 2>/dev/null || true)"
        if [[ "$declaration" == "declare -a"* ]]; then
            previous=("${PROMPT_COMMAND[@]}")
        elif [[ -n "${PROMPT_COMMAND:-}" ]]; then
            previous=("$PROMPT_COMMAND")
        fi

        declare -ga PROMPT_COMMAND=()
        PROMPT_COMMAND+=(limon_runner)
        for item in "${previous[@]}"; do
            [[ "$item" == "limon_runner" ]] || PROMPT_COMMAND+=("$item")
        done
    else
        # shellcheck disable=SC2128,SC2178
        PROMPT_COMMAND="limon_runner${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
}

_limon_prompt_hook_remove() {
    local declaration item
    declaration="$(declare -p PROMPT_COMMAND 2>/dev/null || true)"
    if [[ "$declaration" == "declare -a"* ]]; then
        local -a kept=()
        for item in "${PROMPT_COMMAND[@]}"; do
            [[ "$item" == "limon_runner" ]] || kept+=("$item")
        done
        declare -ga PROMPT_COMMAND=()
        PROMPT_COMMAND=("${kept[@]}")
    else
        # shellcheck disable=SC2178
        case "${PROMPT_COMMAND:-}" in
            limon_runner) PROMPT_COMMAND="" ;;
            "limon_runner; "*) PROMPT_COMMAND="${PROMPT_COMMAND#"limon_runner; "}" ;;
        esac
    fi
}

_limon_prompt_hook_present() {
    local declaration item
    declaration="$(declare -p PROMPT_COMMAND 2>/dev/null || true)"
    if [[ "$declaration" == "declare -a"* ]]; then
        for item in "${PROMPT_COMMAND[@]}"; do
            [[ "$item" == "limon_runner" ]] && return 0
        done
        return 1
    fi
    [[ "${PROMPT_COMMAND:-}" == "limon_runner" || "${PROMPT_COMMAND:-}" == "limon_runner; "* ]]
}

_limon_native_timer_add() {
    _limon_native_timer_remove
    __LIMON_PS0_PREFIX='${__LIMON_PS0[$((__LIMON_CMD_START=SECONDS,__LIMON_CMD_START_US=0,__LIMON_CMD_ACTIVE=1,0))]-}${EPOCHREALTIME:+${__LIMON_PS0[$((__LIMON_CMD_START_US=10#${EPOCHREALTIME/./},0))]-}}'
    PS0="$__LIMON_PS0_PREFIX${PS0-}"
}

_limon_native_timer_remove() {
    if [[ -n "${__LIMON_PS0_PREFIX:-}" && "${PS0-}" == "$__LIMON_PS0_PREFIX"* ]]; then
        PS0="${PS0#"$__LIMON_PS0_PREFIX"}"
    fi
    unset __LIMON_PS0_PREFIX
}

_limon_editor_can_start() {
    [[ $- == *i* && -t 0 && -t 1 && "${TERM:-}" != "dumb" && -n "${TERM:-}" ]]
}

_limon_ble_save_config() {
    [[ "${__LIMON_BLE_CONFIG_SAVED:-0}" == "1" ]] && return 0
    __LIMON_BLE_COMPLETE_AUTO_COMPLETE="${bleopt_complete_auto_complete-}"
    __LIMON_BLE_COMPLETE_AUTO_HISTORY="${bleopt_complete_auto_history-}"
    __LIMON_BLE_COMPLETE_AUTO_DELAY="${bleopt_complete_auto_delay-}"
    __LIMON_BLE_HIGHLIGHT_SYNTAX="${bleopt_highlight_syntax-}"
    __LIMON_BLE_HIGHLIGHT_FILENAME="${bleopt_highlight_filename-}"
    __LIMON_BLE_HIGHLIGHT_VARIABLE="${bleopt_highlight_variable-}"
    __LIMON_BLE_COMPLETE_AMBIGUOUS="${bleopt_complete_ambiguous-}"
    __LIMON_BLE_COMPLETE_MENU_COMPLETE="${bleopt_complete_menu_complete-}"
    __LIMON_BLE_COMPLETE_MENU_FILTER="${bleopt_complete_menu_filter-}"
    __LIMON_BLE_PROMPT_EOL_MARK="${bleopt_prompt_eol_mark-}"
    __LIMON_BLE_EXEC_ERREXIT_MARK="${bleopt_exec_errexit_mark-}"

    local line
    __LIMON_BLE_FACE_AUTO_COMPLETE=""
    while IFS= read -r line; do
        [[ "$line" == "ble-face auto_complete="* ]] &&
            __LIMON_BLE_FACE_AUTO_COMPLETE="${line#*=}"
    done < <(ble-face --color=never auto_complete 2>/dev/null)
    __LIMON_BLE_CONFIG_SAVED=1
}

_limon_ble_configure() {
    command -v bleopt >/dev/null 2>&1 || return 1
    command -v blehook >/dev/null 2>&1 || return 1
    command -v ble-face >/dev/null 2>&1 || return 1

    _limon_ble_save_config
    bleopt highlight_syntax= highlight_filename= highlight_variable= \
        complete_ambiguous= complete_menu_complete= complete_menu_filter= \
        prompt_eol_mark= exec_errexit_mark= >/dev/null 2>&1 || true

    if [[ "${LIMON_AUTOSUGGEST:-1}" == "1" ]]; then
        bleopt complete_auto_complete=1 complete_auto_history=1 \
            "complete_auto_delay=${LIMON_AUTOSUGGEST_DELAY:-100}" >/dev/null 2>&1 || true
        local color="${LIMON_AUTOSUGGEST_COLOR:-auto}"
        [[ "$color" == "auto" ]] && color=242
        ble-face "auto_complete=fg=$color" >/dev/null 2>&1 || true
    else
        bleopt complete_auto_complete= >/dev/null 2>&1 || true
    fi

    # ble.sh binds Alt+Backspace to copy-backward-sword, which copies instead
    # of deleting and ignores "/" as a delimiter. Restore readline's
    # backward-kill-word behaviour, but only in Limon's private instance so a
    # user's own ble.sh bindings are never touched.
    if [[ "${__LIMON_BLE_OWNED:-0}" == "1" ]] && command -v ble-bind >/dev/null 2>&1; then
        local key keymap
        for keymap in emacs vi_imap; do
            for key in 'M-DEL' 'M-BS' 'M-C-?' 'M-C-h'; do
                ble-bind -m "$keymap" -f "$key" kill-backward-cword >/dev/null 2>&1 || true
            done
        done
    fi

    blehook PREEXEC!=_limon_preexec
    blehook PRECMD!=limon_runner
}

_limon_ble_restore() {
    if command -v blehook >/dev/null 2>&1; then
        blehook PREEXEC-=_limon_preexec PRECMD-=limon_runner >/dev/null 2>&1 || true
    fi
    if [[ "${__LIMON_BLE_CONFIG_SAVED:-0}" == "1" ]] && command -v bleopt >/dev/null 2>&1; then
        if [[ "${__LIMON_BLE_OWNED:-0}" == "1" ]]; then
            # ble.sh's supported detach deliberately leaves a recovery command
            # in Readline. Keep Limon's private instance resident but inert;
            # Bash drops it naturally when this shell exits.
            bleopt complete_auto_complete= complete_auto_history= \
                highlight_syntax= highlight_filename= highlight_variable= \
                complete_ambiguous= complete_menu_complete= complete_menu_filter= \
                prompt_eol_mark= exec_errexit_mark= >/dev/null 2>&1 || true
        else
            bleopt \
                "complete_auto_complete=${__LIMON_BLE_COMPLETE_AUTO_COMPLETE-}" \
                "complete_auto_history=${__LIMON_BLE_COMPLETE_AUTO_HISTORY-}" \
                "complete_auto_delay=${__LIMON_BLE_COMPLETE_AUTO_DELAY-}" \
                "highlight_syntax=${__LIMON_BLE_HIGHLIGHT_SYNTAX-}" \
                "highlight_filename=${__LIMON_BLE_HIGHLIGHT_FILENAME-}" \
                "highlight_variable=${__LIMON_BLE_HIGHLIGHT_VARIABLE-}" \
                "complete_ambiguous=${__LIMON_BLE_COMPLETE_AMBIGUOUS-}" \
                "complete_menu_complete=${__LIMON_BLE_COMPLETE_MENU_COMPLETE-}" \
                "complete_menu_filter=${__LIMON_BLE_COMPLETE_MENU_FILTER-}" \
                "prompt_eol_mark=${__LIMON_BLE_PROMPT_EOL_MARK-}" \
                "exec_errexit_mark=${__LIMON_BLE_EXEC_ERREXIT_MARK-}" >/dev/null 2>&1 || true
            if [[ -n "${__LIMON_BLE_FACE_AUTO_COMPLETE:-}" ]] && command -v ble-face >/dev/null 2>&1; then
                ble-face "auto_complete=$__LIMON_BLE_FACE_AUTO_COMPLETE" >/dev/null 2>&1 || true
            fi
        fi
    fi
    unset __LIMON_BLE_CONFIG_SAVED __LIMON_BLE_COMPLETE_AUTO_COMPLETE \
          __LIMON_BLE_COMPLETE_AUTO_HISTORY __LIMON_BLE_COMPLETE_AUTO_DELAY \
          __LIMON_BLE_HIGHLIGHT_SYNTAX __LIMON_BLE_HIGHLIGHT_FILENAME \
          __LIMON_BLE_HIGHLIGHT_VARIABLE __LIMON_BLE_COMPLETE_AMBIGUOUS \
          __LIMON_BLE_COMPLETE_MENU_COMPLETE __LIMON_BLE_COMPLETE_MENU_FILTER \
          __LIMON_BLE_PROMPT_EOL_MARK __LIMON_BLE_EXEC_ERREXIT_MARK \
          __LIMON_BLE_FACE_AUTO_COMPLETE
}

_limon_hooks_remove() {
    _limon_ble_restore
    unset __LIMON_BLE_ATTACHED_BY_LIMON
    _limon_prompt_hook_remove
    _limon_native_timer_remove
    __LIMON_HOOK_PROVIDER=none
}

_limon_bash_completion_state() {
    if [[ -n "${BASH_COMPLETION_VERSINFO[0]:-}" ]]; then
        echo "loaded (${BASH_COMPLETION_VERSINFO[*]})"
    elif complete -p 2>/dev/null | grep -qv ' limon$'; then
        echo "loaded"
    elif [[ -r /usr/share/bash-completion/bash_completion || -r /etc/bash_completion ]]; then
        echo "available, not loaded"
    else
        echo "not found (history, commands, and paths still work)"
    fi
}

# --- Phase 9: Trust & diagnostics ---
_limon_validate_theme_file() {
    local file="$1"
    local warnings=0
    local line key val

    [[ -f "$file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            case "$key" in
                col_ok|col_err|col_git|col_dir|col_host|col_time|\
                theme_multiline|theme_separator|theme_symbol_prefix|theme_max_path) ;;
                *)
                    echo "limon: theme warning: unknown variable '$key' in $file" >&2
                    ((warnings++)) || true
                    ;;
            esac
            if [[ "$key" == col_* ]]; then
                if ! _limon_brackets_balanced "$val"; then
                    echo "limon: theme warning: unbalanced \\[ \\] in $key ($file)" >&2
                    ((warnings++)) || true
                fi
            fi
        else
            echo "limon: theme warning: invalid line in $file: $line" >&2
            ((warnings++)) || true
        fi
    done < "$file"

    return "$warnings"
}

_limon_health_msg() {
    printf '  %-4s %s\n' "$1" "$2"
}

_limon_do_health() {
    local issues=0 warnings=0 theme_path tw

    echo "Limon health check (v$LIMON_VERSION)"
    echo ""

    if (( BASH_VERSINFO[0] > 4 || BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4 )); then
        _limon_health_msg OK "bash ${BASH_VERSION}"
    else
        _limon_health_msg FAIL "bash ${BASH_VERSION} (4.4+ required)"
        ((issues++)) || true
    fi

    if _limon_use_color; then
        if command -v tput >/dev/null 2>&1; then
            local colors
            colors="$(tput colors 2>/dev/null || echo 0)"
            if [[ "${colors:-0}" -ge 256 ]]; then
                _limon_health_msg OK "256-color terminal (tput colors=$colors, TERM=${TERM:-unknown})"
            elif [[ "${colors:-0}" -ge 8 ]]; then
                _limon_health_msg WARN "basic colors only (tput colors=$colors; 256 recommended)"
                ((warnings++)) || true
            else
                _limon_health_msg WARN "color support limited (tput colors=$colors)"
                ((warnings++)) || true
            fi
        else
            _limon_health_msg WARN "tput not found; 256-color support unverified"
            ((warnings++)) || true
        fi
    else
        _limon_health_msg OK "no-color mode (TERM=${TERM:-unknown})"
    fi

    if command -v git >/dev/null 2>&1; then
        _limon_health_msg OK "git $(git --version 2>/dev/null | awk '{print $3}')"
    else
        _limon_health_msg WARN "git not found (git segment unavailable)"
        ((warnings++)) || true
    fi

    if [[ -f "$LIMON_CONF" ]]; then
        _limon_health_msg OK "config $LIMON_CONF"
    else
        _limon_health_msg WARN "config file missing (using defaults)"
        ((warnings++)) || true
    fi

    theme_path="$(_limon_resolve_theme_file "$saved_theme" 2>/dev/null || true)"
    if [[ -n "$theme_path" ]]; then
        if _limon_validate_theme_file "$theme_path"; then
            _limon_health_msg OK "theme '$saved_theme' ($theme_path)"
        else
            tw=$?
            _limon_health_msg WARN "theme '$saved_theme' has $tw warning(s)"
            ((warnings+=tw)) || true
        fi
    else
        _limon_health_msg WARN "theme '$saved_theme' not found (using built-in defaults)"
        ((warnings++)) || true
    fi

    if _limon_is_active; then
        _limon_health_msg OK "prompt active"
        if _limon_brackets_balanced "${PS1:-}"; then
            _limon_health_msg OK "PS1 \\[ \\] markers balanced"
        else
            _limon_health_msg FAIL "PS1 has unbalanced \\[ \\] markers"
            ((issues++)) || true
        fi
        case "${__LIMON_HOOK_PROVIDER:-none}" in
            ble)
                local ble_hooks=""
                command -v blehook >/dev/null 2>&1 && ble_hooks="$(blehook PREEXEC PRECMD 2>/dev/null || true)"
                if [[ "$ble_hooks" == *"_limon_preexec"* && "$ble_hooks" == *"limon_runner"* ]]; then
                    _limon_health_msg OK "timer and prompt use ble.sh PREEXEC/PRECMD hooks"
                else
                    _limon_health_msg FAIL "ble.sh hooks are incomplete"
                    ((issues++)) || true
                fi
                ;;
            native)
                if _limon_prompt_hook_present && [[ "${PS0-}" == "${__LIMON_PS0_PREFIX:-missing}"* ]]; then
                    _limon_health_msg OK "timer uses PS0; prompt uses composable PROMPT_COMMAND"
                else
                    _limon_health_msg FAIL "native prompt or timer hook is missing"
                    ((issues++)) || true
                fi
                ;;
            *)
                _limon_health_msg FAIL "prompt active but hook provider is unknown"
                ((issues++)) || true
                ;;
        esac
    else
        _limon_health_msg OK "prompt off"
        if _limon_prompt_hook_present; then
            _limon_health_msg FAIL "limon_runner still in PROMPT_COMMAND (run 'limon off')"
            ((issues++)) || true
        else
            _limon_health_msg OK "clean PROMPT_COMMAND (no limon_runner)"
        fi
    fi

    local debug_trap
    debug_trap="$(trap -p DEBUG 2>/dev/null || true)"
    if [[ "$debug_trap" == *"_limon_preexec"* ]]; then
        _limon_health_msg FAIL "legacy Limon DEBUG trap is still installed"
        ((issues++)) || true
    else
        _limon_health_msg OK "no Limon DEBUG trap"
    fi

    if [[ "${LIMON_AUTOSUGGEST:-1}" == "1" ]]; then
        case "${__LIMON_EDITOR_PROVIDER:-none}" in
            ble-bundled) _limon_health_msg OK "ghost autosuggestions (bundled ble.sh ${BLE_VERSION:-unknown})" ;;
            ble-external) _limon_health_msg OK "ghost autosuggestions (existing ble.sh ${BLE_VERSION:-unknown})" ;;
            *)
                _limon_health_msg WARN "ghost autosuggestions unavailable in this session"
                ((warnings++)) || true
                ;;
        esac
    else
        _limon_health_msg OK "ghost autosuggestions disabled by config"
    fi
    _limon_health_msg OK "bash-completion $(_limon_bash_completion_state)"

    if [[ -r "$SCRIPT_DIR/limon.sh" ]]; then
        _limon_health_msg OK "install $SCRIPT_DIR"
    else
        _limon_health_msg FAIL "limon.sh not readable at $SCRIPT_DIR"
        ((issues++)) || true
    fi

    if _limon_is_git_install; then
        if [[ -w "$SCRIPT_DIR/.git" ]]; then
            _limon_health_msg OK "git install is writable (upgrades supported)"
        else
            _limon_health_msg WARN "git install not writable (use sudo for limon upgrade)"
            ((warnings++)) || true
        fi
    else
        # Not a failure — a tarball install is perfectly fine, it just updates
        # differently. Saying nothing here left users guessing.
        _limon_health_msg OK "not a git install ('limon upgrade' unavailable)"
        _limon_health_msg "" "update with: $LIMON_INSTALL_ONELINER"
    fi

    local hp_theme="${LIMON_THEME_ARG:-${saved_theme:-default}}" hp_ps1="$PS1" hp_t0 hp_t1 hp_n=20 hp_i
    _limon_clock_us; hp_t0="$__LIMON_T"
    if [[ -n "$hp_t0" ]]; then
        for (( hp_i = 0; hp_i < hp_n; hp_i++ )); do _limon_main "$hp_theme" >/dev/null 2>&1; done
        _limon_clock_us; hp_t1="$__LIMON_T"
        PS1="$hp_ps1"
        _limon_health_msg OK "render ~$(_limon_fmt_ms $(( (hp_t1 - hp_t0) / hp_n ))) avg over $hp_n runs (see 'limon bench')"
    else
        _limon_health_msg WARN "render timing unavailable (needs bash 5+ or GNU date)"
        ((warnings++)) || true
    fi
    local hp_rss
    hp_rss="$(_limon_rss_kb)"
    [[ -n "$hp_rss" ]] && _limon_health_msg OK "memory ${hp_rss} KB RSS (whole bash process)"

    echo ""
    if [[ $issues -eq 0 ]]; then
        if [[ $warnings -eq 0 ]]; then
            echo "Result: healthy"
        else
            echo "Result: healthy with $warnings warning(s)"
        fi
        return 0
    fi
    echo "Result: $issues issue(s), $warnings warning(s)"
    return 1
}

# --- Phase 5: Safe rendering helpers ---
_limon_use_color() {
    [[ "${LIMON_NO_COLOR:-}" == "1" ]] && return 1
    [[ "${TERM:-}" == "dumb" || -z "${TERM:-}" ]] && return 1
    [[ -t 1 ]] || return 1
    return 0
}

_limon_count_markers() {
    local s="$1" marker="$2" count=0
    while [[ "$s" == *"$marker"* ]]; do
        ((count++))
        s="${s#*"$marker"}"
    done
    echo "$count"
}

_limon_brackets_balanced() {
    local s="$1"
    [[ $(_limon_count_markers "$s" '\[') -eq $(_limon_count_markers "$s" '\]') ]]
}

_limon_init_symbols() {
    if [[ "${LIMON_ASCII:-0}" == "1" ]]; then
        __LIMON_SYM_LOCK="#"
        __LIMON_SYM_ARROW=">"
        __LIMON_SYM_UP="^"
        __LIMON_SYM_DOWN="v"
        __LIMON_SYM_WARN="!"
        __LIMON_SYM_STASH="="
        __LIMON_SYM_FAIL="x"
    else
        __LIMON_SYM_LOCK=" 🔒"
        __LIMON_SYM_ARROW="➜ "
        __LIMON_SYM_UP="↑"
        __LIMON_SYM_DOWN="↓"
        __LIMON_SYM_WARN="⚠"
        __LIMON_SYM_STASH="≡"
        __LIMON_SYM_FAIL="✗"
    fi
}

# Sets __LIMON_ASCII_OUT to the ASCII transliteration of "$1".
#
# Every helper on the render path returns through a global rather than stdout:
# a command substitution forks a subshell, and the prompt is rebuilt on every
# single command. See _limon_clock_us for the original instance of this pattern.
_limon_ascii_text() {
    local s="$1"
    s="${s//↑/$__LIMON_SYM_UP}"
    s="${s//↓/$__LIMON_SYM_DOWN}"
    s="${s//➜ /$__LIMON_SYM_ARROW}"
    s="${s//➜/$__LIMON_SYM_ARROW}"
    s="${s//🔒/$__LIMON_SYM_LOCK}"
    s="${s//⚠/$__LIMON_SYM_WARN}"
    s="${s//≡/$__LIMON_SYM_STASH}"
    s="${s//✗/$__LIMON_SYM_FAIL}"
    __LIMON_ASCII_OUT="$s"
}

# --- Phase 8: Exit-code clarity ---
# Sets __LIMON_EXIT_HINT to a short label for an exit code; returns 1 if there
# is no useful label for it.
_limon_exit_hint() {
    local code="$1"
    __LIMON_EXIT_HINT=""
    case "$code" in
        1) __LIMON_EXIT_HINT="error" ;;
        2) __LIMON_EXIT_HINT="builtin" ;;
        126) __LIMON_EXIT_HINT="not executable" ;;
        127) __LIMON_EXIT_HINT="not found" ;;
        130) __LIMON_EXIT_HINT="SIGINT" ;;
        137) __LIMON_EXIT_HINT="SIGKILL" ;;
        143) __LIMON_EXIT_HINT="SIGTERM" ;;
        1[2-9][0-9]) __LIMON_EXIT_HINT="signal$((code - 128))" ;;
        *) return 1 ;;
    esac
}

# Sets __LIMON_SYMBOL to the trailing prompt symbol, including the exit-code
# badge when show_exit is on.
_limon_prompt_symbol() {
    local last_exit="$1"
    local col_ok="$2"
    local col_err="$3"
    local c_reset="$4"
    local theme_symbol_prefix="$5"

    local prompt_char="$"
    [[ "${EUID}" -eq 0 ]] && prompt_char="#"

    local symbol_str="$col_ok"
    [[ "$last_exit" -ne 0 ]] && symbol_str="$col_err"

    if [[ "$last_exit" -ne 0 && "${LIMON_SHOW_EXIT:-0}" == "1" ]]; then
        local exit_label="${__LIMON_SYM_FAIL}${last_exit}"
        if [[ "${LIMON_EXIT_HINTS:-0}" == "1" ]]; then
            if _limon_exit_hint "$last_exit" 2>/dev/null && [[ -n "$__LIMON_EXIT_HINT" ]]; then
                exit_label+="(${__LIMON_EXIT_HINT})"
            fi
        fi
        if [[ -n "$theme_symbol_prefix" ]]; then
            __LIMON_SYMBOL="${symbol_str}${theme_symbol_prefix}${exit_label} ${prompt_char} ${c_reset}"
        else
            __LIMON_SYMBOL="${symbol_str}${exit_label} ${prompt_char} ${c_reset}"
        fi
        return
    fi

    [[ -n "$theme_symbol_prefix" ]] && symbol_str="${symbol_str}${theme_symbol_prefix}"
    __LIMON_SYMBOL="${symbol_str}${prompt_char} ${c_reset}"
}

# --- Phase 6: Identity & safety helpers ---
# Sets __LIMON_HOSTCOL to a 256-color index for the host segment; returns 1 when
# host coloring is off, leaving the caller on the theme's own host color.
#
# The hash is cached on the hostname: it never changes within a shell, and the
# old implementation forked a subshell for every single character of it.
_limon_host_color_code() {
    local mode="${LIMON_HOST_COLOR:-off}"

    if [[ "$mode" == "off" || "$mode" == "0" ]]; then
        return 1
    fi

    if [[ "$mode" =~ ^[0-9]+$ ]]; then
        __LIMON_HOSTCOL="$mode"
        return 0
    fi

    [[ "$mode" == "auto" ]] || return 1

    local host="${HOSTNAME:-}"
    if [[ -z "$host" ]]; then
        host="$(hostname 2>/dev/null)"
        HOSTNAME="$host"
    fi

    if [[ "${__LIMON_HOSTCOL_FOR:-}" == "$host" && -n "${__LIMON_HOSTCOL:-}" ]]; then
        return 0
    fi

    local hash=0 i c
    for (( i = 0; i < ${#host}; i++ )); do
        printf -v c '%d' "'${host:$i:1}"
        hash=$(( (hash * 31 + c) % 216 ))
    done

    __LIMON_HOSTCOL=$(( 32 + hash % 200 ))
    __LIMON_HOSTCOL_FOR="$host"
    return 0
}

_limon_has_sudo_ticket() {
    [[ "${LIMON_SHOW_SUDO:-1}" != "1" ]] && return 1
    [[ "${EUID}" -eq 0 ]] && return 1
    local ts
    for ts in "/run/sudo/ts/$(id -u 2>/dev/null)" "/var/db/sudo/ts/$(id -u 2>/dev/null)"; do
        [[ -f "$ts" ]] && return 0
    done
    return 1
}

# Sets __LIMON_K8S_LABEL to the kubectl context badge; returns 1 when there is
# nothing to show.
_limon_k8s_label() {
    __LIMON_K8S_LABEL=""
    [[ "${LIMON_K8S:-0}" != "1" ]] && return 1

    if [[ -n "${KUBE_PS1_CONTEXT:-}" ]]; then
        __LIMON_K8S_LABEL="(k8s:$KUBE_PS1_CONTEXT)"
        return 0
    fi

    if [[ $((SECONDS - ${__LIMON_K8S_CACHE_SEC:-0})) -lt 2 && -n "${__LIMON_K8S_CACHE_CTX:-}" ]]; then
        __LIMON_K8S_LABEL="(k8s:$__LIMON_K8S_CACHE_CTX)"
        return 0
    fi

    if ! command -v kubectl >/dev/null 2>&1; then
        return 1
    fi

    local ctx
    ctx="$(kubectl config current-context 2>/dev/null)" || return 1
    __LIMON_K8S_CACHE_CTX="$ctx"
    __LIMON_K8S_CACHE_SEC=$SECONDS
    __LIMON_K8S_LABEL="(k8s:$ctx)"
}

# Sets __LIMON_SAFETY to the leading banner segment (root warning, environment
# label, sudo ticket, cloud profile, kubectl context).
_limon_safety_prefix() {
    local c_reset="$1"
    local col_err="$2"
    local prefix=""

    if [[ "${EUID}" -eq 0 && "${LIMON_SHOW_ROOT:-0}" == "1" ]]; then
        prefix+="${col_err}[${__LIMON_SYM_WARN} ROOT]${c_reset} "
    fi

    if [[ "${LIMON_ENV_BANNER:-0}" == "1" && -n "${LIMON_ENV:-}" ]]; then
        local env_label="${LIMON_ENV^^}"
        local col_banner='\[\e[38;5;244m\]'
        case "${LIMON_ENV,,}" in
            prod|production) col_banner='\[\e[38;5;196m\]' ;;
            staging|stage) col_banner='\[\e[38;5;226m\]' ;;
            dev|development) col_banner='\[\e[38;5;39m\]' ;;
        esac
        if [[ -z "$c_reset" ]]; then
            col_banner=''
        fi
        prefix+="${col_banner}[${__LIMON_SYM_WARN} ${env_label}]${c_reset} "
    fi

    if _limon_has_sudo_ticket; then
        prefix+="${c_reset}(sudo) "
    fi

    if [[ "${LIMON_CLOUD:-0}" == "1" && -n "${AWS_PROFILE:-}" ]]; then
        prefix+="${c_reset}(aws:$AWS_PROFILE) "
    fi

    if _limon_k8s_label 2>/dev/null && [[ -n "$__LIMON_K8S_LABEL" ]]; then
        prefix+="${c_reset}${__LIMON_K8S_LABEL} "
    fi

    __LIMON_SAFETY="$prefix"
}

# Sets __LIMON_PATH to the directory segment, collapsing $HOME to ~ and
# truncating to at most "$1" characters (0 disables truncation).
_limon_display_path() {
    local max="$1"
    local path="$PWD"

    # The "~" here is a literal character for display, not a path to expand.
    # shellcheck disable=SC2088
    if [[ -n "$HOME" ]]; then
        if [[ "$path" == "$HOME" ]]; then
            path="~"
        elif [[ "$path" == "$HOME/"* ]]; then
            path="~/${path#"$HOME"/}"
        fi
    fi

    if [[ ! "$max" =~ ^[0-9]+$ ]] || (( max <= 0 )) || (( ${#path} <= max )); then
        __LIMON_PATH="$path"
        return
    fi

    # Split off the root marker so it survives truncation, then drop leading
    # components one at a time until the result fits. 'rest' always contains a
    # '/' at the top of the loop and strictly shrinks, so this always terminates.
    local prefix="" rest="$path"
    # shellcheck disable=SC2088  # literal "~" for display, not expansion
    if [[ "$path" == "~/"* ]]; then
        prefix="~/"; rest="${path#\~/}"
    elif [[ "$path" == /* ]]; then
        prefix="/"; rest="${path#/}"
    fi

    local candidate
    while [[ "$rest" == */* ]]; do
        rest="${rest#*/}"
        candidate="${prefix}…/${rest}"
        if (( ${#candidate} <= max )); then
            __LIMON_PATH="$candidate"
            return
        fi
    done

    # A single component that still overflows: keep its rightmost characters.
    # Guard the offset — "${rest: -N}" with N greater than the length yields "".
    if (( max <= 1 )); then
        __LIMON_PATH="${rest: -1}"
    elif (( ${#rest} > max - 1 )); then
        __LIMON_PATH="…${rest: -$((max - 1))}"
    else
        __LIMON_PATH="…${rest}"
    fi
}

# --- Metrics helpers ---
# Sets __LIMON_T to the current time in integer microseconds, or "" if no
# high-resolution clock is available. Uses bash 5's $EPOCHREALTIME with no
# subprocess; falls back to GNU `date +%s%N` only when necessary.
_limon_clock_us() {
    if [[ -n "${EPOCHREALTIME:-}" ]]; then
        local t="${EPOCHREALTIME/,/.}"
        local s="${t%.*}" us="${t#*.}"
        us="${us}000000"
        us="${us:0:6}"
        __LIMON_T="${s}${us}"
    else
        local n
        n="$(date +%s%N 2>/dev/null)"
        if [[ "$n" =~ ^[0-9]{16,}$ ]]; then
            __LIMON_T=$(( n / 1000 ))
        else
            __LIMON_T=""
        fi
    fi
}

# Resident memory of the current shell process, in KB ("" if unavailable).
# Note: this is the whole bash process, not limon alone.
_limon_rss_kb() {
    local kb=""
    if [[ -r "/proc/$$/status" ]]; then
        while IFS=$' \t' read -r key val _; do
            if [[ "$key" == "VmRSS:" ]]; then kb="$val"; break; fi
        done < "/proc/$$/status"
    fi
    if [[ -z "$kb" ]] && command -v ps >/dev/null 2>&1; then
        kb="$(ps -o rss= -p "$$" 2>/dev/null | tr -d ' ')"
    fi
    [[ "$kb" =~ ^[0-9]+$ ]] && echo "$kb"
}

# Sets __LIMON_THRESHOLD_MS from LIMON_TIMER_THRESHOLD, which is expressed in
# seconds and may carry one or more decimal places (e.g. 2, 0.5, 1.25).
_limon_threshold_ms() {
    local spec="${LIMON_TIMER_THRESHOLD:-2}"

    if [[ "${__LIMON_THRESHOLD_FOR:-}" == "$spec" ]]; then
        return 0
    fi

    local whole frac
    if [[ "$spec" =~ ^([0-9]*)\.([0-9]+)$ ]]; then
        whole="${BASH_REMATCH[1]:-0}"
        frac="${BASH_REMATCH[2]}000"
        frac="${frac:0:3}"
    elif [[ "$spec" =~ ^[0-9]+$ ]]; then
        whole="$spec"
        frac="000"
    else
        whole=2
        frac="000"
    fi

    __LIMON_THRESHOLD_MS=$(( 10#$whole * 1000 + 10#$frac ))
    __LIMON_THRESHOLD_FOR="$spec"
}

# Sets __LIMON_ELAPSED_STR to a human-readable duration for "$1" milliseconds.
#
# Under a minute it keeps one decimal place ("1.4s"); above that it switches to
# whole seconds ("2m 03s"), where tenths stop being useful.
#
# "$2" says whether the measurement actually has sub-second resolution (default
# yes). On bash 4 there is no fork-free high-resolution clock, so the timer
# falls back to whole seconds — printing "1.0s" there would advertise a
# precision the number does not have, so it renders "1s" instead.
_limon_format_elapsed() {
    local ms="$1"
    local hires="${2:-1}"
    (( ms < 0 )) && ms=0

    if (( ms < 60000 )); then
        if [[ "$hires" == "1" ]]; then
            __LIMON_ELAPSED_STR="$(( ms / 1000 )).$(( (ms % 1000) / 100 ))s"
        else
            __LIMON_ELAPSED_STR="$(( ms / 1000 ))s"
        fi
        return
    fi

    local total_sec=$(( ms / 1000 ))
    local min=$(( total_sec / 60 ))
    local sec=$(( total_sec % 60 ))
    if (( min >= 60 )); then
        printf -v __LIMON_ELAPSED_STR '%dh %02dm %02ds' \
            $(( min / 60 )) $(( min % 60 )) "$sec"
    else
        printf -v __LIMON_ELAPSED_STR '%dm %02ds' "$min" "$sec"
    fi
}

# Format integer microseconds as "N.NNN ms".
_limon_fmt_ms() {
    local us="$1"
    (( us < 0 )) && us=0
    printf '%d.%03d ms' $(( us / 1000 )) $(( us % 1000 ))
}

# Benchmark prompt rendering: limon bench [iterations]
# Times one segment "$iters" times and prints its share of a render.
# Sets __LIMON_SEG_US so the caller can tally what the parts add up to.
_limon_bench_segment() {
    local label="$1" iters="$2"; shift 2
    local t0 t1 i
    _limon_clock_us; t0="$__LIMON_T"
    for (( i = 0; i < iters; i++ )); do
        "$@" >/dev/null 2>&1
    done
    _limon_clock_us; t1="$__LIMON_T"
    __LIMON_SEG_US=$(( (t1 - t0) / iters ))
    (( __LIMON_SEG_US < 0 )) && __LIMON_SEG_US=0
    printf '  %-22s %s\n' "$label" "$(_limon_fmt_ms "$__LIMON_SEG_US")"
}

# Per-segment timings, so a regression can be attributed rather than guessed at.
_limon_do_bench_breakdown() {
    local iters="${1:-100}"
    local theme="${LIMON_THEME_ARG:-${saved_theme:-default}}"

    _limon_clock_us
    if [[ -z "$__LIMON_T" ]]; then
        echo "limon bench: no high-resolution timer (needs bash 5+ or GNU date)." >&2
        return 1
    fi

    echo "Limon prompt benchmark — per segment"
    printf '  theme: %s, git mode: %s, %d iterations each\n\n' \
        "$theme" "${LIMON_GIT_MODE:-full}" "$iters"

    local parts=0

    _limon_bench_segment "theme (cached)" "$iters" _limon_load_theme "$theme"
    parts=$(( parts + __LIMON_SEG_US ))
    _limon_bench_segment "git info" "$iters" _limon_git_info
    parts=$(( parts + __LIMON_SEG_US ))
    _limon_bench_segment "safety prefix" "$iters" _limon_safety_prefix "" ""
    parts=$(( parts + __LIMON_SEG_US ))
    _limon_bench_segment "path" "$iters" _limon_display_path "${LIMON_MAX_PATH:-40}"
    parts=$(( parts + __LIMON_SEG_US ))
    _limon_bench_segment "prompt symbol" "$iters" _limon_prompt_symbol 0 "" "" "" ""
    parts=$(( parts + __LIMON_SEG_US ))
    _limon_bench_segment "host color" "$iters" _limon_host_color_code
    parts=$(( parts + __LIMON_SEG_US ))
    _limon_bench_segment "symbols" "$iters" _limon_init_symbols
    parts=$(( parts + __LIMON_SEG_US ))

    local saved_ps1="$PS1" t0 t1 i
    _limon_clock_us; t0="$__LIMON_T"
    for (( i = 0; i < iters; i++ )); do
        _limon_main "$theme" >/dev/null 2>&1
    done
    _limon_clock_us; t1="$__LIMON_T"
    PS1="$saved_ps1"

    local whole_us=$(( (t1 - t0) / iters ))
    (( whole_us < 0 )) && whole_us=0

    printf '\n  %-22s %s\n' "segments total" "$(_limon_fmt_ms "$parts")"
    printf '  %-22s %s\n' "whole render" "$(_limon_fmt_ms "$whole_us")"
}

_limon_do_bench() {
    if [[ "${1:-}" == "--breakdown" || "${1:-}" == "-b" ]]; then
        _limon_do_bench_breakdown "${2:-100}"
        return
    fi

    local iters="${1:-100}"
    [[ "$iters" =~ ^[0-9]+$ ]] || iters=100
    (( iters < 1 )) && iters=1

    local theme="${LIMON_THEME_ARG:-${saved_theme:-default}}"
    local saved_ps1="$PS1"
    local t0 t1

    _limon_clock_us; t0="$__LIMON_T"
    if [[ -z "$t0" ]]; then
        echo "limon bench: no high-resolution timer (needs bash 5+ or GNU date)." >&2
        PS1="$saved_ps1"
        return 1
    fi

    local i
    for (( i = 0; i < iters; i++ )); do
        _limon_main "$theme" >/dev/null 2>&1
    done

    _limon_clock_us; t1="$__LIMON_T"
    PS1="$saved_ps1"

    local total_us=$(( t1 - t0 ))
    (( total_us < 0 )) && total_us=0
    local avg_us=$(( total_us / iters ))

    echo "Limon prompt benchmark"
    printf '  theme:       %s\n' "$theme"
    printf '  git mode:    %s\n' "${LIMON_GIT_MODE:-full}"
    printf '  iterations:  %d\n' "$iters"
    printf '  total:       %s\n' "$(_limon_fmt_ms "$total_us")"
    printf '  per render:  %s (avg)\n' "$(_limon_fmt_ms "$avg_us")"

    local rss
    rss="$(_limon_rss_kb)"
    if [[ -n "$rss" ]]; then
        printf '  shell RSS:   %d KB (~%d MB, whole bash process)\n' "$rss" $(( rss / 1024 ))
    fi

    if [[ "${LIMON_GIT_MODE:-full}" != "off" ]]; then
        echo "  tip: most cost is the git status call; 'limon config git=lite' or 'git=off' is faster."
    fi
}

# --- Auto-update helpers ---
_limon_is_git_install() {
    command -v git >/dev/null 2>&1 && [[ -d "$SCRIPT_DIR/.git" ]]
}

# Ignore executable-bit-only diffs (e.g. after `chmod +x install.sh`) so upgrades work.
_limon_git_prepare_repo() {
    git -C "$SCRIPT_DIR" config core.fileMode false 2>/dev/null || true
}

# Map an update channel name to its git branch. Prints nothing for unknown names.
#   stable -> master   (tested, recommended)
#   beta   -> beta     (newest features, may be unstable)
#   dev    -> dev      (active development, expect breakage)
_limon_channel_branch() {
    case "$1" in
        stable) echo "master" ;;
        beta)   echo "beta" ;;
        dev)    echo "dev" ;;
        *)      return 1 ;;
    esac
}

# Quietly fetch and compare against the channel branch. Used in the background.
# Marks an update as available (or auto-pulls when autoupdate=on and on-branch).
_limon_background_update_check() {
    _limon_is_git_install || return 0
    _limon_git_prepare_repo

    local branch
    branch="$(_limon_channel_branch "${LIMON_CHANNEL:-stable}")" || branch="master"

    git -C "$SCRIPT_DIR" --no-optional-locks fetch --quiet origin 2>/dev/null || return 0

    local current_branch local_rev remote_rev
    current_branch="$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0
    remote_rev="$(git -C "$SCRIPT_DIR" rev-parse "origin/$branch" 2>/dev/null)" || return 0
    local_rev="$(git -C "$SCRIPT_DIR" rev-parse @ 2>/dev/null)" || return 0

    # On a different branch than the configured channel: a switch is available.
    if [[ "$current_branch" != "$branch" ]]; then
        : > "$LIMON_UPDATE_FLAG"
        return 0
    fi
    [[ -z "$remote_rev" || "$local_rev" == "$remote_rev" ]] && { rm -f "$LIMON_UPDATE_FLAG"; return 0; }

    if [[ "$LIMON_AUTOUPDATE" == "on" && -w "$SCRIPT_DIR/.git" ]]; then
        if git -C "$SCRIPT_DIR" merge --quiet --ff-only "origin/$branch" 2>/dev/null; then
            rm -f "$LIMON_UPDATE_FLAG"
            return 0
        fi
    fi
    : > "$LIMON_UPDATE_FLAG"
}

# Called from `limon on`. Shows a pending notice and, if due, spawns a
# detached background check so the prompt is never delayed.
_limon_maybe_autoupdate() {
    [[ "${LIMON_AUTOUPDATE:-off}" == "off" ]] && return 0
    _limon_is_git_install || return 0

    if [[ -f "$LIMON_UPDATE_FLAG" ]]; then
        echo "limon: a new version is available. Run 'limon upgrade' to update."
    fi

    local now last=0
    now="$(date +%s 2>/dev/null)" || return 0
    [[ -f "$LIMON_UPDATE_STAMP" ]] && last="$(cat "$LIMON_UPDATE_STAMP" 2>/dev/null || echo 0)"
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    (( now - last < LIMON_UPDATE_INTERVAL )) && return 0

    echo "$now" > "$LIMON_UPDATE_STAMP" 2>/dev/null || true
    ( _limon_background_update_check ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

# Load (or reload) the tab-completion hints into the current interactive shell.
# Pass "force" to re-source even if completion is already registered (used after
# an upgrade so updated completion logic takes effect without a new shell).
_limon_load_hints() {
    local force="${1:-}"
    case $- in *i*) ;; *) return 0 ;; esac
    command -v complete >/dev/null 2>&1 || return 0
    if [[ "$force" != "force" ]] && complete -p limon >/dev/null 2>&1; then
        return 0
    fi
    local hint="$SCRIPT_DIR/hint-limon.sh"
    # shellcheck source=hint-limon.sh
    [[ -f "$hint" ]] && source "$hint"
}

# Persist the chosen channel to the config file (keeps theme + other flags intact).
_limon_save_channel() {
    LIMON_CHANNEL="$1"
    local _flags
    mapfile -t _flags < <(_limon_conf_flags)
    _limon_write_config "$saved_theme" "${_flags[@]}"
    export LIMON_CHANNEL
}

# Manual, foreground updater for `limon upgrade [stable|beta|dev]`.
# With no argument it updates on the currently configured channel.
_limon_do_upgrade() {
    local requested_channel="${1:-}"

    if ! command -v git >/dev/null 2>&1; then
        echo "limon: git is required to upgrade." >&2
        return 1
    fi
    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        echo "limon: this copy cannot update itself ($SCRIPT_DIR is not a git install)." >&2
        echo "limon: to update, run the installer again:" >&2
        echo "limon:   $LIMON_INSTALL_ONELINER" >&2
        echo "limon: that also restores 'limon upgrade' if git is available." >&2
        return 1
    fi
    if [[ ! -w "$SCRIPT_DIR/.git" ]]; then
        echo "limon: no write permission for $SCRIPT_DIR." >&2
        echo "limon: try: sudo git -C \"$SCRIPT_DIR\" pull --ff-only" >&2
        return 1
    fi

    # Resolve which channel/branch to upgrade to.
    local channel="${LIMON_CHANNEL:-stable}"
    [[ -n "$requested_channel" ]] && channel="$requested_channel"

    local branch
    if ! branch="$(_limon_channel_branch "$channel")"; then
        echo "limon: unknown channel '$channel' (use: stable, beta, dev)." >&2
        return 1
    fi

    # Persist the channel if the user explicitly switched it.
    if [[ -n "$requested_channel" && "$requested_channel" != "${LIMON_CHANNEL:-stable}" ]]; then
        _limon_save_channel "$requested_channel"
        echo "limon: switched update channel to '$channel'."
    fi

    # Ignore executable-bit changes so a user's `chmod +x install.sh` (or similar)
    # doesn't register as a local modification that blocks a fast-forward pull.
    _limon_git_prepare_repo

    echo "limon: channel '$channel' (branch '$branch') — checking $SCRIPT_DIR ..."
    if ! git -C "$SCRIPT_DIR" --no-optional-locks fetch --quiet origin 2>/dev/null; then
        echo "limon: failed to fetch from 'origin'." >&2
        return 1
    fi

    if ! git -C "$SCRIPT_DIR" rev-parse --verify --quiet "origin/$branch" >/dev/null 2>&1; then
        echo "limon: remote branch 'origin/$branch' not found." >&2
        return 1
    fi

    # Switch to the channel branch if we're not already on it.
    local current_branch
    current_branch="$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [[ "$current_branch" != "$branch" ]]; then
        echo "limon: switching branch '$current_branch' -> '$branch' ..."
        if ! git -C "$SCRIPT_DIR" checkout "$branch" >/dev/null 2>&1 && \
           ! git -C "$SCRIPT_DIR" checkout -b "$branch" --track "origin/$branch" >/dev/null 2>&1; then
            echo "limon: could not switch to branch '$branch'." >&2
            echo "limon: you may have local changes — check: git -C \"$SCRIPT_DIR\" status" >&2
            return 1
        fi
    fi

    local local_rev remote_rev
    local_rev="$(git -C "$SCRIPT_DIR" rev-parse @ 2>/dev/null)"
    remote_rev="$(git -C "$SCRIPT_DIR" rev-parse "origin/$branch" 2>/dev/null)"
    if [[ -n "$remote_rev" && "$local_rev" == "$remote_rev" ]]; then
        echo "limon: already up to date on '$channel'."
        rm -f "$LIMON_UPDATE_FLAG"
        return 0
    fi

    if git -C "$SCRIPT_DIR" merge --ff-only "origin/$branch"; then
        rm -f "$LIMON_UPDATE_FLAG"
        _limon_load_hints force
        echo "limon: updated to the latest '$channel' (tab-completion reloaded)."
        echo "limon: run 'limon on' or open a new terminal to load the new prompt code."
        if [[ "$channel" != "stable" ]]; then
            echo "limon: note: '$channel' may be unstable. Switch back with: limon upgrade stable"
        fi
    else
        echo "limon: update failed (local changes or non-fast-forward history)." >&2
        echo "limon: inspect with: git -C \"$SCRIPT_DIR\" status" >&2
        return 1
    fi
}

# --- Phase 10: UX helpers ---
_limon_user_theme_path() {
    local theme_name="$1"
    echo "$LIMON_CONF_DIR/themes/${theme_name}.theme"
}

_limon_write_theme_template() {
    local theme_file="$1"
    cat > "$theme_file" <<'EOF'
# Limon Theme Template

col_ok='\[\e[38;5;44m\]'
col_err='\[\e[38;5;196m\]'
col_git='\[\e[38;5;214m\]'
col_dir='\[\e[38;5;39m\]'
col_host='\[\e[38;5;118m\]'
col_time='\[\e[38;5;242m\]'

theme_multiline=0
theme_separator=":"
theme_symbol_prefix=""
theme_max_path=0
EOF
}

_limon_ensure_user_theme() {
    local theme_name="$1"
    local user_file resolved
    user_file="$(_limon_user_theme_path "$theme_name")"
    mkdir -p "$LIMON_CONF_DIR/themes"

    if [[ -f "$user_file" ]]; then
        echo "$user_file"
        return 0
    fi

    resolved="$(_limon_resolve_theme_file "$theme_name" 2>/dev/null || true)"
    if [[ -n "$resolved" && "$resolved" != "$user_file" ]]; then
        cp "$resolved" "$user_file"
        echo "$user_file"
        return 0
    fi

    _limon_write_theme_template "$user_file"
    echo "$user_file"
}

_limon_do_edit() {
    local theme_name="${1:-$saved_theme}"
    local editor="${EDITOR:-${VISUAL:-vi}}"
    local theme_file

    theme_file="$(_limon_ensure_user_theme "$theme_name")"
    echo "limon: editing $theme_file"
    "$editor" "$theme_file"

    if _limon_is_active && [[ "$saved_theme" == "$theme_name" ]]; then
        unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
              __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
              __LIMON_GIT_CACHE_DETACHED __LIMON_STASH_CACHE_SEC __LIMON_STASH_CACHE
        _limon_invalidate_theme_cache
        LAST_EXIT_CODE=${LAST_EXIT_CODE:-0}
        limon_runner
    fi
}

_limon_expand_ps1() {
    local ps1="$1"
    ps1="${ps1//\\u/${USER:-user}}"
    ps1="${ps1//\\h/${HOSTNAME:-$(hostname 2>/dev/null || echo host)}}"
    ps1="${ps1//\\w/$PWD}"
    ps1="${ps1//\\\[}"
    ps1="${ps1//\\\]}"
    ps1="${ps1//\\n/$'\n'}"
    printf '%b' "$ps1"
}

_limon_do_preview() {
    local theme_name="${1:-default}"
    local saved_ps1="${PS1:-}"
    local saved_exit="${LAST_EXIT_CODE:-0}"
    local theme_path

    LAST_EXIT_CODE=0
    _limon_main "$theme_name"
    local preview_ps1="$PS1"
    export PS1="$saved_ps1"
    LAST_EXIT_CODE="$saved_exit"

    theme_path="$(_limon_resolve_theme_file "$theme_name" 2>/dev/null || true)"
    echo "Theme: $theme_name"
    if [[ -n "$theme_path" ]]; then
        echo "File: $theme_path"
    else
        echo "File: (built-in defaults)"
    fi
    echo ""
    _limon_expand_ps1 "$preview_ps1"
    echo ""
}

# Restore the current shell's prompt and remove only state owned by Limon.
_limon_restore_session() {
    __LIMON_ACTIVE=0
    _limon_hooks_remove
    __LIMON_EDITOR_PROVIDER=inactive
    export PS1="${DEFAULT_PS1:-}"
    unset timer LAST_EXIT_CODE 2>/dev/null || true
    unset __LIMON_CMD_START __LIMON_CMD_START_US __LIMON_CMD_ELAPSED \
          __LIMON_CMD_ELAPSED_MS __LIMON_TIMER_HIRES __LIMON_CMD_ACTIVE __LIMON_IN_PROMPT \
          __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
          __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
          __LIMON_GIT_CACHE_DETACHED __LIMON_STASH_CACHE_SEC __LIMON_STASH_CACHE
}

# Run the installer's uninstall flow, then clean up the live shell session.
_limon_do_uninstall() {
    local installer="$SCRIPT_DIR/install.sh"
    if [[ ! -f "$installer" ]]; then
        echo "limon: installer not found at $installer." >&2
        echo "limon: remove Limon manually, or re-download install.sh to uninstall." >&2
        return 1
    fi

    bash "$installer" --uninstall "$@"
    local rc=$?

    _limon_restore_session
    return "$rc"
}

# --- 3. Subcommand & Config Loading ---
# Skipped entirely under LIMON_SOURCE_ONLY (see the test hook before section 7), so
# sourcing the script for its functions never parses a subcommand or writes config.
if [[ -z "${LIMON_SOURCE_ONLY:-}" ]]; then

SUBCOMMAND="${1:-}"
shift || true

_limon_load_config

THEME_NAME="${1:-}"
if [[ -z "$THEME_NAME" ]]; then
    case "$SUBCOMMAND" in
        on|edit) THEME_NAME="$saved_theme" ;;
    esac
fi

# --- 4. Save State ---
if [[ "$SUBCOMMAND" == "on" ]]; then
    mapfile -t _limon_flags < <(_limon_conf_flags)
    _limon_write_config "$THEME_NAME" "${_limon_flags[@]}"
    if ! _limon_theme_exists "$THEME_NAME"; then
        echo "limon: theme '$THEME_NAME' not found, using built-in defaults" >&2
    fi
fi

# These stay shell variables rather than environment variables: the prompt
# renderer runs in this shell via PROMPT_COMMAND, and subshells inherit
# shell variables anyway, so exporting them only pollutes the environment
# of every child process.

fi  # end LIMON_SOURCE_ONLY guard over sections 3-4

# --- 5. Git Info (single call + short cache) ---
# Sets __LIMON_GIT_DIR to this repo's git directory, cached per working
# directory. One rev-parse then serves both the in-progress-operation check and
# the stash count instead of one fork each.
_limon_git_resolve_dir() {
    if [[ "${__LIMON_GIT_DIR_PWD:-}" == "$PWD" ]]; then
        [[ -n "${__LIMON_GIT_DIR:-}" ]] && return 0 || return 1
    fi
    __LIMON_GIT_DIR_PWD="$PWD"
    __LIMON_GIT_DIR="$(git --no-optional-locks rev-parse --git-dir 2>/dev/null)" || {
        __LIMON_GIT_DIR=""
        return 1
    }
    [[ -n "$__LIMON_GIT_DIR" ]] || return 1
}

# Sets __LIMON_GIT_OP to the in-progress operation, or returns 1 if there is none.
_limon_git_op_state() {
    __LIMON_GIT_OP=""
    _limon_git_resolve_dir || return 1
    local git_dir="$__LIMON_GIT_DIR"
    if [[ -f "$git_dir/MERGE_HEAD" ]]; then
        __LIMON_GIT_OP="MERGING"
    elif [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
        __LIMON_GIT_OP="REBASING"
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
        __LIMON_GIT_OP="CHERRY-PICK"
    else
        return 1
    fi
}

# Sets __LIMON_STASH_COUNT to the number of stash entries.
#
# The stash is a reflog, so its entries can be counted by reading the log file
# directly. That replaces "git stash list | wc -l | tr -d ' '" — a git process
# plus two more in a pipeline — with one file read, on a path that runs for
# every prompt inside a repo. Falls back to git when the file is unreadable
# (worktrees and unusual layouts).
_limon_git_stash_count() {
    if [[ $((SECONDS - ${__LIMON_STASH_CACHE_SEC:-0})) -lt 2 && "${__LIMON_STASH_CACHE:-}" =~ ^[0-9]+$ ]]; then
        __LIMON_STASH_COUNT="$__LIMON_STASH_CACHE"
        return
    fi

    local count=0
    local stash_log="${__LIMON_GIT_DIR:-}/logs/refs/stash"
    if [[ -n "${__LIMON_GIT_DIR:-}" && -r "$stash_log" ]]; then
        local line
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" ]] && (( count++ ))
        done < "$stash_log"
    elif [[ -n "${__LIMON_GIT_DIR:-}" ]]; then
        # No stash reflog means no stashes.
        count=0
    else
        local listed
        listed="$(git --no-optional-locks stash list 2>/dev/null | wc -l | tr -d ' ')"
        count="${listed:-0}"
    fi

    __LIMON_STASH_CACHE="$count"
    __LIMON_STASH_CACHE_SEC=$SECONDS
    __LIMON_STASH_COUNT="$count"
}

_limon_git_lite() {
    __LIMON_GIT_BRANCH=""
    __LIMON_GIT_MARKS=""
    __LIMON_GIT_IN_REPO=0

    if ! command -v git >/dev/null 2>&1; then
        return
    fi

    local branch
    branch="$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)" || \
    branch="$(git --no-optional-locks rev-parse --short HEAD 2>/dev/null)" || return

    __LIMON_GIT_BRANCH="$branch"
    __LIMON_GIT_IN_REPO=1
}

# Sets: __LIMON_GIT_BRANCH, __LIMON_GIT_MARKS, __LIMON_GIT_IN_REPO, __LIMON_GIT_DETACHED
_limon_git_info() {
    __LIMON_GIT_BRANCH=""
    __LIMON_GIT_MARKS=""
    __LIMON_GIT_IN_REPO=0
    __LIMON_GIT_DETACHED=0

    case "${LIMON_GIT_MODE:-full}" in
        off) return ;;
        lite) _limon_git_lite; return ;;
    esac

    if ! command -v git >/dev/null 2>&1; then
        return
    fi

    if [[ "${__LIMON_GIT_CACHE_PWD:-}" == "$PWD" && \
          "${__LIMON_GIT_CACHE_ASCII:-}" == "${LIMON_ASCII:-0}" && \
          "${__LIMON_GIT_CACHE_MODE:-}" == "${LIMON_GIT_MODE:-full}" && \
          $((SECONDS - ${__LIMON_GIT_CACHE_SEC:-0})) -lt 1 ]]; then
        __LIMON_GIT_BRANCH="$__LIMON_GIT_CACHE_BRANCH"
        __LIMON_GIT_MARKS="$__LIMON_GIT_CACHE_MARKS"
        __LIMON_GIT_DETACHED="${__LIMON_GIT_CACHE_DETACHED:-0}"
        __LIMON_GIT_IN_REPO=1
        return
    fi

    local line push_count=0 pull_count=0 got_branch=0
    local staged=0 unstaged=0 untracked=0
    local marks=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^## ]]; then
            got_branch=1
            if [[ "$line" =~ ^##\ No\ commits\ yet\ on\ (.+) ]]; then
                __LIMON_GIT_BRANCH="${BASH_REMATCH[1]}"
            elif [[ "$line" == *"detached at"* ]]; then
                __LIMON_GIT_BRANCH="${line#*detached at }"
                __LIMON_GIT_BRANCH="${__LIMON_GIT_BRANCH%)}"
                __LIMON_GIT_DETACHED=1
            elif [[ "$line" =~ ^##\ (HEAD\ \(no\ branch\)) ]]; then
                __LIMON_GIT_BRANCH="${BASH_REMATCH[1]}"
                __LIMON_GIT_DETACHED=1
            elif [[ "$line" =~ ^##\ ([^.[:space:]]+) ]]; then
                __LIMON_GIT_BRANCH="${BASH_REMATCH[1]}"
            fi
            [[ "$line" =~ ahead\ ([0-9]+) ]] && push_count=${BASH_REMATCH[1]}
            [[ "$line" =~ behind\ ([0-9]+) ]] && pull_count=${BASH_REMATCH[1]}
        elif [[ "$line" == \?\?* ]]; then
            ((untracked++)) || true
        else
            local x="${line:0:1}" y="${line:1:1}"
            [[ "$x" != " " && "$x" != "?" ]] && ((staged++)) || true
            [[ "$y" != " " ]] && ((unstaged++)) || true
        fi
    done < <(git --no-optional-locks status --porcelain --branch 2>/dev/null)

    if [[ $got_branch -eq 1 ]]; then
        __LIMON_GIT_IN_REPO=1

        if _limon_git_op_state 2>/dev/null && [[ -n "$__LIMON_GIT_OP" ]]; then
            marks+=" {$__LIMON_GIT_OP}"
        fi

        [[ "${__LIMON_GIT_DETACHED:-0}" == "1" ]] && marks+=" (DETACHED)"

        if [[ "${LIMON_GIT_MODE:-full}" == "verbose" ]]; then
            [[ $staged -gt 0 ]] && marks+=" +$staged"
            [[ $unstaged -gt 0 ]] && marks+=" ~$unstaged"
            [[ $untracked -gt 0 ]] && marks+=" ?$untracked"
        else
            [[ $staged -gt 0 || $unstaged -gt 0 ]] && marks+=" (@)"
            [[ $untracked -gt 0 ]] && marks+=" ?"
        fi

        local stash_n
        _limon_git_resolve_dir 2>/dev/null || true
        _limon_git_stash_count 2>/dev/null || __LIMON_STASH_COUNT=0
        stash_n="${__LIMON_STASH_COUNT:-0}"
        [[ "${stash_n:-0}" -gt 0 ]] && marks+=" ≡${stash_n}"

        [[ $push_count -gt 0 ]] && marks+=" ↑$push_count"
        [[ $pull_count -gt 0 ]] && marks+=" ↓$pull_count"

        __LIMON_GIT_MARKS="$marks"

        _limon_init_symbols
        if [[ "${LIMON_ASCII:-0}" == "1" ]]; then
            _limon_ascii_text "$__LIMON_GIT_MARKS"
            __LIMON_GIT_MARKS="$__LIMON_ASCII_OUT"
        fi

        __LIMON_GIT_CACHE_PWD="$PWD"
        __LIMON_GIT_CACHE_SEC=$SECONDS
        __LIMON_GIT_CACHE_ASCII="${LIMON_ASCII:-0}"
        __LIMON_GIT_CACHE_MODE="${LIMON_GIT_MODE:-full}"
        __LIMON_GIT_CACHE_BRANCH="$__LIMON_GIT_BRANCH"
        __LIMON_GIT_CACHE_MARKS="$__LIMON_GIT_MARKS"
        __LIMON_GIT_CACHE_DETACHED="${__LIMON_GIT_DETACHED:-0}"
    else
        unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
              __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
              __LIMON_GIT_CACHE_DETACHED
    fi
}

# --- 6. Main Prompt Function ---
# Resolves, validates, and sources a theme once, caching the result in
# __LIMON_THEME_* globals.
#
# _limon_main() used to do this on every render: a full line-by-line regex validation
# pass plus a `source` of the theme file for each prompt, which dominated the
# render cost and re-printed any theme warnings on every keypress. The cache is
# keyed on the theme name; `limon reload`, `limon edit`, and `limon config`
# invalidate it explicitly so an edited theme still takes effect.
_limon_load_theme() {
    local theme_name="${1:-default}"

    [[ "${__LIMON_THEME_NAME:-}" == "$theme_name" ]] && return 0

    # Built-in defaults; a theme file overrides only the keys it sets.
    local col_ok='\[\e[38;5;44m\]'
    local col_err='\[\e[38;5;160m\]'
    local col_git='\[\e[38;5;214m\]'
    local col_dir='\[\e[38;5;39m\]'
    local col_host='\[\e[38;5;118m\]'
    local col_time='\[\e[38;5;242m\]'
    local theme_multiline=0
    local theme_separator=":"
    local theme_symbol_prefix=""
    local theme_max_path=0

    local theme_file
    theme_file="$(_limon_resolve_theme_file "$theme_name" 2>/dev/null || true)"
    if [[ -n "$theme_file" ]]; then
        _limon_validate_theme_file "$theme_file" || true
        # Theme files are user data resolved at runtime; validated just above.
        # shellcheck disable=SC1090
        source "$theme_file"
    fi

    __LIMON_THEME_NAME="$theme_name"
    __LIMON_THEME_FILE="$theme_file"
    __LIMON_THEME_COL_OK="$col_ok"
    __LIMON_THEME_COL_ERR="$col_err"
    __LIMON_THEME_COL_GIT="$col_git"
    __LIMON_THEME_COL_DIR="$col_dir"
    __LIMON_THEME_COL_HOST="$col_host"
    __LIMON_THEME_COL_TIME="$col_time"
    __LIMON_THEME_MULTILINE="$theme_multiline"
    __LIMON_THEME_SEPARATOR="$theme_separator"
    __LIMON_THEME_SYMBOL_PREFIX="$theme_symbol_prefix"
    __LIMON_THEME_MAX_PATH="$theme_max_path"
}

# Drops the cached theme so the next render re-reads it from disk.
_limon_invalidate_theme_cache() {
    unset __LIMON_THEME_NAME __LIMON_THEME_FILE
}

_limon_main() {
    local last_exit="${LAST_EXIT_CODE:-0}"
    local theme_name="${1:-default}"

    _limon_load_theme "$theme_name"

    local col_ok="$__LIMON_THEME_COL_OK"
    local col_err="$__LIMON_THEME_COL_ERR"
    local col_git="$__LIMON_THEME_COL_GIT"
    local col_dir="$__LIMON_THEME_COL_DIR"
    local col_host="$__LIMON_THEME_COL_HOST"
    local col_time="$__LIMON_THEME_COL_TIME"
    local theme_multiline="$__LIMON_THEME_MULTILINE"
    local theme_separator="$__LIMON_THEME_SEPARATOR"
    local theme_symbol_prefix="$__LIMON_THEME_SYMBOL_PREFIX"
    local theme_max_path="$__LIMON_THEME_MAX_PATH"

    local c_reset='\[\e[m\]'
    local c_gray='\[\e[38;5;240m\]'

    if ! _limon_use_color; then
        col_ok='' col_err='' col_git='' col_dir='' col_host='' col_time=''
        c_reset='' c_gray=''
    fi

    _limon_init_symbols
    if [[ "${LIMON_ASCII:-0}" == "1" ]]; then
        _limon_ascii_text "$theme_symbol_prefix"
        theme_symbol_prefix="$__LIMON_ASCII_OUT"
    fi

    if _limon_use_color && _limon_host_color_code 2>/dev/null; then
        col_host='\[\e[38;5;'${__LIMON_HOSTCOL}'m\]'
    fi

    _limon_safety_prefix "$c_reset" "$col_err"
    local safety_str="$__LIMON_SAFETY"

    local elapsed_str=""
    _limon_threshold_ms
    if (( ${__LIMON_CMD_ELAPSED_MS:-0} >= __LIMON_THRESHOLD_MS )); then
        _limon_format_elapsed "${__LIMON_CMD_ELAPSED_MS:-0}" "${__LIMON_TIMER_HIRES:-1}"
        elapsed_str=" $__LIMON_ELAPSED_STR"
    fi

    local git_str=""
    _limon_git_info
    if [[ ${__LIMON_GIT_IN_REPO:-0} -eq 1 ]]; then
        local git_color="$col_git"
        [[ "${__LIMON_GIT_DETACHED:-0}" == "1" ]] && git_color="$col_err"
        if [[ "$theme_multiline" -eq 1 ]]; then
            git_str="$git_color$__LIMON_GIT_MARKS ($__LIMON_GIT_BRANCH)"
        else
            git_str="$git_color$__LIMON_GIT_MARKS [$__LIMON_GIT_BRANCH]"
        fi
    fi

    local env_parts=()
    [[ -n "${VIRTUAL_ENV:-}" ]] && env_parts+=("(venv)")
    [[ -n "${CONDA_DEFAULT_ENV:-}" ]] && env_parts+=("(conda:$CONDA_DEFAULT_ENV)")
    [[ -n "${DOCKER_MACHINE_NAME:-}" ]] && env_parts+=("(dkr:$DOCKER_MACHINE_NAME)")
    local venv_str=""
    if [[ ${#env_parts[@]} -gt 0 ]]; then
        local part
        venv_str="$c_reset"
        for part in "${env_parts[@]}"; do
            venv_str+="$part "
        done
    fi

    local host_str=""
    if [[ "${LIMON_SHOW_HOST:-1}" == "1" ]]; then
        local ssh_prefix=""
        if [[ "${LIMON_SHOW_SSH:-0}" == "1" && -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}" ]]; then
            ssh_prefix="[ssh] "
        fi
        host_str="$col_host${ssh_prefix}\u@\h"
    fi

    local dir_color=$col_dir
    local lock_icon=""
    local path_max="${theme_max_path:-0}"
    [[ "$path_max" -eq 0 ]] && path_max="${LIMON_MAX_PATH:-0}"

    if [[ ! -w . ]]; then
        lock_icon="$__LIMON_SYM_LOCK"
        [[ "${EUID}" -ne 0 ]] && dir_color=$c_gray
    fi
    if [[ "${EUID}" -eq 0 && "$PWD" != /root* && "$PWD" != /home* && "$PWD" == /* ]]; then
        dir_color=$col_err
    fi

    local path_display=""
    if [[ "$path_max" =~ ^[0-9]+$ && "$path_max" -gt 0 ]]; then
        _limon_display_path "$path_max"
        path_display="$__LIMON_PATH"
    fi

    local dir_str=""
    if [[ -n "$path_display" ]]; then
        dir_str="$dir_color${path_display}${lock_icon}"
    else
        dir_str="$dir_color\w$lock_icon"
    fi

    local time_display=""
    if [[ "${LIMON_SHOW_CLOCK:-0}" == "1" ]]; then
        local now_hm
        printf -v now_hm '%(%H:%M)T' -1
        time_display+="$col_time$now_hm "
    fi
    [[ -n "$elapsed_str" ]] && time_display+="$col_time$elapsed_str "

    # Counting jobs needs the builtin's output, and capturing builtin output in
    # bash always costs a subshell. Guard it with `jobs -r %%`, which reports
    # whether any running job exists without capturing anything: ~6us versus
    # ~460us, and the expensive path is only taken when there is something to
    # count. (The original "jobs -rp | wc -l | tr -d ' '" cost three processes.)
    local jobs_str=""
    if jobs -r %% >/dev/null 2>&1; then
        local running_jobs
        mapfile -t running_jobs < <(jobs -rp 2>/dev/null)
        [[ "${#running_jobs[@]}" -gt 0 ]] && jobs_str="[${#running_jobs[@]}] "
    fi

    _limon_prompt_symbol "$last_exit" "$col_ok" "$col_err" "$c_reset" "$theme_symbol_prefix"
    local symbol_str="$__LIMON_SYMBOL"

    local ps1=""
    if [[ "$theme_multiline" -eq 1 ]]; then
        if [[ -n "$host_str" ]]; then
            ps1="$safety_str$venv_str$host_str $dir_str$git_str$time_display$jobs_str\n$symbol_str"
        else
            ps1="$safety_str$venv_str$dir_str$git_str$time_display$jobs_str\n$symbol_str"
        fi
    else
        if [[ -n "$host_str" ]]; then
            ps1="$safety_str$venv_str$host_str$theme_separator$dir_str$git_str$time_display$jobs_str$symbol_str"
        else
            ps1="$safety_str$venv_str$dir_str$git_str$time_display$jobs_str$symbol_str"
        fi
    fi

    if [[ "${LIMON_DEBUG:-}" == "1" ]] && ! _limon_brackets_balanced "$ps1"; then
        echo "limon: warning: unbalanced \\[ \\] markers in PS1" >&2
    fi

    export PS1="$ps1"
}
# Exported so it survives into the PROMPT_COMMAND context. Deliberately NOT
# named "main": an exported function by that name is inherited by every child
# bash process, where any script that calls main before defining it would run
# Limon's prompt renderer instead.
export -f _limon_main

# --- 7. Runner ---
limon_runner() {
    LAST_EXIT_CODE=$?
    __LIMON_IN_PROMPT=1
    if [[ "${__LIMON_CMD_ACTIVE:-0}" == "1" && -n "${__LIMON_CMD_START:-}" ]]; then
        __LIMON_CMD_ELAPSED=$((SECONDS - __LIMON_CMD_START))
        if [[ -n "${__LIMON_CMD_START_US:-}" && -n "${EPOCHREALTIME:-}" ]]; then
            _limon_clock_us
            __LIMON_CMD_ELAPSED_MS=$(( (__LIMON_T - __LIMON_CMD_START_US) / 1000 ))
            (( __LIMON_CMD_ELAPSED_MS < 0 )) && __LIMON_CMD_ELAPSED_MS=0
            __LIMON_TIMER_HIRES=1
        else
            __LIMON_CMD_ELAPSED_MS=$(( __LIMON_CMD_ELAPSED * 1000 ))
            __LIMON_TIMER_HIRES=0
        fi
    else
        __LIMON_CMD_ELAPSED=0
        __LIMON_CMD_ELAPSED_MS=0
    fi
    : "${__LIMON_TIMER_HIRES:=1}"
    __LIMON_CMD_ACTIVE=0
    if [[ "${LIMON_METRICS:-0}" == "1" ]]; then
        local __limon_a __limon_b
        _limon_clock_us; __limon_a="$__LIMON_T"
        _limon_main "$LIMON_THEME_ARG"
        _limon_clock_us; __limon_b="$__LIMON_T"
        if [[ -n "$__limon_a" && -n "$__limon_b" ]]; then
            __LIMON_RENDER_US=$(( __limon_b - __limon_a ))
            (( __LIMON_RENDER_US < 0 )) && __LIMON_RENDER_US=0
            export __LIMON_RENDER_US
        fi
    else
        _limon_main "$LIMON_THEME_ARG"
    fi
    __LIMON_IN_PROMPT=0
}
export -f limon_runner
export -f _limon_preexec
export -f _limon_clock_us

# Test hook: with LIMON_SOURCE_ONLY set, every function above is now defined but no
# subcommand is dispatched and the prompt is never installed. tests/ relies on this.
if [[ -n "${LIMON_SOURCE_ONLY:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Only 'limon on' changes the live theme. Other subcommands (status, config,
# upgrade, etc.) must preserve the currently active theme so their argument
# (e.g. a channel name or config key) doesn't leak into the prompt renderer.
if [[ "$SUBCOMMAND" == "on" ]]; then
    export LIMON_THEME_ARG="$THEME_NAME"
else
    export LIMON_THEME_ARG="${LIMON_THEME_ARG:-$saved_theme}"
fi

case "$SUBCOMMAND" in
    on)
        __LIMON_ACTIVE=0
        _limon_hooks_remove
        # Neutralize the 1.1.x timing hook during an in-place upgrade. Limon
        # 1.2 never installs a DEBUG trap of its own.
        if [[ "$(trap -p DEBUG 2>/dev/null || true)" == *"_limon_preexec"* ]]; then
            trap '' DEBUG 2>/dev/null || true
        fi

        __LIMON_ACTIVE=1
        __LIMON_EDITOR_PROVIDER=native
        __LIMON_HOOK_PROVIDER=native

        if _limon_editor_can_start && [[ -n "${BLE_VERSION:-}" ]]; then
            if [[ "${__LIMON_BLE_OWNED:-0}" == "1" ]]; then
                __LIMON_EDITOR_PROVIDER=ble-bundled
            else
                __LIMON_EDITOR_PROVIDER=ble-external
            fi
        elif _limon_editor_can_start && [[ "${LIMON_AUTOSUGGEST:-1}" == "1" ]] &&
             [[ -r "$SCRIPT_DIR/vendor/blesh/ble.sh" ]]; then
            # This source must stay at top level. ble.sh explicitly recommends
            # against loading its editor from inside a shell function.
            __LIMON_BLE_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
            if mkdir -p "$__LIMON_BLE_CACHE_ROOT" 2>/dev/null; then
                # shellcheck source=/dev/null
                if source -- "$SCRIPT_DIR/vendor/blesh/ble.sh" --attach=none --norc; then
                    __LIMON_BLE_OWNED=1
                    __LIMON_EDITOR_PROVIDER=ble-bundled
                else
                    echo "limon: bundled autosuggestion engine failed to load; using native prompt hooks" >&2
                fi
            else
                echo "limon: cannot create the editor cache; using native prompt hooks" >&2
            fi
            unset __LIMON_BLE_CACHE_ROOT
        fi

        if [[ "$__LIMON_EDITOR_PROVIDER" == ble-* ]] && _limon_ble_configure; then
            __LIMON_HOOK_PROVIDER=ble
        else
            __LIMON_EDITOR_PROVIDER=native
            __LIMON_HOOK_PROVIDER=native
            _limon_prompt_hook_add
            _limon_native_timer_add
        fi

        LAST_EXIT_CODE=${LAST_EXIT_CODE:-0}
        __LIMON_CMD_ELAPSED=0
        __LIMON_CMD_ACTIVE=0
        limon_runner
        _limon_load_hints
        _limon_maybe_autoupdate

        if [[ "$__LIMON_HOOK_PROVIDER" == "ble" && -z "${_ble_attached:-}" ]]; then
            __LIMON_BLE_ATTACHED_BY_LIMON=1
            if ! ble-attach; then
                echo "limon: autosuggestion editor could not attach; using native prompt hooks" >&2
                _limon_ble_restore
                unset __LIMON_BLE_ATTACHED_BY_LIMON
                __LIMON_EDITOR_PROVIDER=native
                __LIMON_HOOK_PROVIDER=native
                _limon_prompt_hook_add
                _limon_native_timer_add
            fi
        fi
        ;;
    upgrade|update)
        _limon_do_upgrade "${1:-}"
        ;;
    uninstall)
        _limon_do_uninstall "$@"
        ;;
    off)
        _limon_restore_session
        # Disarm a hook left behind when upgrading an already-running 1.1.x
        # session. Fresh 1.2 sessions never touch DEBUG.
        if [[ "$(trap -p DEBUG 2>/dev/null || true)" == *"_limon_preexec"* ]]; then
            trap '' DEBUG 2>/dev/null || true
        fi
        ;;
    reload)
        if ! _limon_is_active; then
            echo "limon: not active (run 'limon on' first)" >&2
        elif [[ -z "${__LIMON_RELOADING:-}" && -f "$SCRIPT_DIR/limon.sh" ]]; then
            # Re-source the script so `reload` picks up new code, not just new
            # config — otherwise a shell open across `limon upgrade` keeps
            # running the old renderer. The guard stops the nested `on` from
            # recursing back into this arm.
            __LIMON_RELOADING=1
            _limon_invalidate_theme_cache
            # shellcheck source=limon.sh
            source "$SCRIPT_DIR/limon.sh" on "$saved_theme"
            unset __LIMON_RELOADING
        else
            unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
                  __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
                  __LIMON_GIT_CACHE_DETACHED __LIMON_STASH_CACHE_SEC __LIMON_STASH_CACHE
            _limon_invalidate_theme_cache
            _limon_load_config
            # These stay shell variables rather than environment variables: the prompt
            # renderer runs in this shell via PROMPT_COMMAND, and subshells inherit
            # shell variables anyway, so exporting them only pollutes the environment
            # of every child process.
            export LIMON_THEME_ARG="$saved_theme"
            LAST_EXIT_CODE=${LAST_EXIT_CODE:-0}
            limon_runner
        fi
        ;;
    status)
        if _limon_is_active; then
            echo "Limon: on"
        else
            echo "Limon: off"
        fi
        echo "Version: $LIMON_VERSION"
        echo "Theme: $saved_theme"
        theme_path="$(_limon_resolve_theme_file "$saved_theme" 2>/dev/null || true)"
        if [[ -n "$theme_path" ]]; then
            echo "Theme file: $theme_path"
        else
            echo "Theme file: (built-in defaults)"
        fi
        echo "Config: $LIMON_CONF"
        echo "Options: timer_threshold=$LIMON_TIMER_THRESHOLD git=$LIMON_GIT_MODE show_host=$LIMON_SHOW_HOST show_ssh=$LIMON_SHOW_SSH autoupdate=$LIMON_AUTOUPDATE ascii=$LIMON_ASCII max_path=$LIMON_MAX_PATH"
        echo "Safety: host_color=$LIMON_HOST_COLOR env_banner=$LIMON_ENV_BANNER show_root=$LIMON_SHOW_ROOT show_sudo=$LIMON_SHOW_SUDO k8s=$LIMON_K8S cloud=$LIMON_CLOUD show_exit=$LIMON_SHOW_EXIT exit_hints=$LIMON_EXIT_HINTS clock=$LIMON_SHOW_CLOCK metrics=$LIMON_METRICS"
        echo "Autosuggest: enabled=$LIMON_AUTOSUGGEST delay=${LIMON_AUTOSUGGEST_DELAY}ms color=$LIMON_AUTOSUGGEST_COLOR provider=${__LIMON_EDITOR_PROVIDER:-inactive}"
        echo "Hooks: ${__LIMON_HOOK_PROVIDER:-none}; bash-completion=$(_limon_bash_completion_state)"
        if [[ "$LIMON_METRICS" == "1" && -n "${__LIMON_RENDER_US:-}" ]]; then
            echo "Last render: $(_limon_fmt_ms "$__LIMON_RENDER_US") (run 'limon bench' for an average)"
        elif [[ "$LIMON_METRICS" == "1" ]]; then
            echo "Last render: (no sample yet — press Enter once, then run 'limon status')"
        fi
        status_rss="$(_limon_rss_kb)"
        if [[ -n "$status_rss" ]]; then
            echo "Memory: ${status_rss} KB RSS (whole bash process)"
        fi
        if [[ -n "${LIMON_ENV:-}" ]]; then
            echo "Environment: LIMON_ENV=$LIMON_ENV"
        fi
        if _limon_use_color; then
            echo "Rendering: color=on term=${TERM:-unknown}"
        else
            echo "Rendering: color=off term=${TERM:-unknown}"
        fi
        if _limon_is_git_install; then
            status_branch="$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
            echo "Install: $SCRIPT_DIR (git — upgradable)"
            echo "Channel: $LIMON_CHANNEL (branch: $status_branch)"
        else
            echo "Install: $SCRIPT_DIR (not a git install — update by re-running the installer)"
            echo "Update:  $LIMON_INSTALL_ONELINER"
            echo "Channel: $LIMON_CHANNEL (not a git install)"
        fi
        if [[ -f "$LIMON_UPDATE_FLAG" ]]; then
            echo "Update: a new version is available (run 'limon upgrade')"
        fi
        ;;
    themes)
        listed=0
        while IFS= read -r name; do
            listed=1
            path="$(_limon_resolve_theme_file "$name" 2>/dev/null || true)"
            if [[ -n "$path" ]]; then
                printf '  %-12s %s\n' "$name" "$path"
            else
                printf '  %-12s (built-in defaults)\n' "$name"
            fi
        done < <(_limon_list_themes | sort)
        if [[ $listed -eq 0 ]]; then
            echo "No themes found."
        fi
        ;;
    health)
        _limon_do_health
        ;;
    bench|benchmark)
        _limon_do_bench "${1:-}" "${2:-}"
        ;;
    edit)
        _limon_do_edit "${THEME_NAME:-$saved_theme}"
        ;;
    preview)
        if [[ -z "${THEME_NAME:-}" ]]; then
            echo "limon: usage: limon preview <theme>" >&2
        else
            _limon_do_preview "$THEME_NAME"
        fi
        ;;
    config)
        CONFIG_ARG="${1:-}"
        if [[ -z "$CONFIG_ARG" ]]; then
            echo "Usage: limon config timer_threshold=N|git=full|lite|off|show_host=0|1|show_ssh=0|1|autoupdate=off|notify|on|channel=stable|beta|dev|ascii=0|1|max_path=N|host_color=auto|off|N|env_banner=0|1|show_root=0|1|show_sudo=0|1|k8s=0|1|cloud=0|1|show_exit=0|1|exit_hints=0|1|clock=0|1|metrics=0|1|autosuggest=0|1|autosuggest_delay=0..2000|autosuggest_color=auto|0..255"
            echo "Current: timer_threshold=$LIMON_TIMER_THRESHOLD git=$LIMON_GIT_MODE show_host=$LIMON_SHOW_HOST show_ssh=$LIMON_SHOW_SSH autoupdate=$LIMON_AUTOUPDATE channel=$LIMON_CHANNEL ascii=$LIMON_ASCII max_path=$LIMON_MAX_PATH"
            echo "         host_color=$LIMON_HOST_COLOR env_banner=$LIMON_ENV_BANNER show_root=$LIMON_SHOW_ROOT show_sudo=$LIMON_SHOW_SUDO k8s=$LIMON_K8S cloud=$LIMON_CLOUD show_exit=$LIMON_SHOW_EXIT exit_hints=$LIMON_EXIT_HINTS clock=$LIMON_SHOW_CLOCK metrics=$LIMON_METRICS"
            echo "         autosuggest=$LIMON_AUTOSUGGEST autosuggest_delay=$LIMON_AUTOSUGGEST_DELAY autosuggest_color=$LIMON_AUTOSUGGEST_COLOR"
        else
            config_ok=0
            case "$CONFIG_ARG" in
                timer_threshold=*)
                    if [[ "${CONFIG_ARG#*=}" =~ ^[0-9]+$ || "${CONFIG_ARG#*=}" =~ ^[0-9]*\.[0-9]+$ ]]; then
                        LIMON_TIMER_THRESHOLD="${CONFIG_ARG#*=}"
                        config_ok=1
                    else
                        echo "limon: timer_threshold must be a non-negative number of seconds (e.g. 2 or 0.5)" >&2
                    fi
                    ;;
                git=*)
                    case "${CONFIG_ARG#*=}" in
                        full|lite|verbose|off) LIMON_GIT_MODE="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: git must be full, lite, verbose, or off" >&2 ;;
                    esac
                    ;;
                show_host=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_SHOW_HOST="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: show_host must be 0 or 1" >&2 ;;
                    esac
                    ;;
                show_ssh=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_SHOW_SSH="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: show_ssh must be 0 or 1" >&2 ;;
                    esac
                    ;;
                autoupdate=*)
                    case "${CONFIG_ARG#*=}" in
                        off|notify|on) LIMON_AUTOUPDATE="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: autoupdate must be one of: off, notify, on" >&2 ;;
                    esac
                    ;;
                channel=*)
                    case "${CONFIG_ARG#*=}" in
                        stable|beta|dev) LIMON_CHANNEL="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: channel must be one of: stable, beta, dev" >&2 ;;
                    esac
                    ;;
                ascii=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_ASCII="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: ascii must be 0 or 1" >&2 ;;
                    esac
                    ;;
                max_path=*)
                    if [[ "${CONFIG_ARG#*=}" =~ ^[0-9]+$ ]]; then
                        LIMON_MAX_PATH="${CONFIG_ARG#*=}"
                        config_ok=1
                    else
                        echo "limon: max_path must be a non-negative integer" >&2
                    fi
                    ;;
                host_color=*)
                    case "${CONFIG_ARG#*=}" in
                        auto|off) LIMON_HOST_COLOR="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *)
                            if [[ "${CONFIG_ARG#*=}" =~ ^[0-9]+$ && "${CONFIG_ARG#*=}" -le 255 ]]; then
                                LIMON_HOST_COLOR="${CONFIG_ARG#*=}"
                                config_ok=1
                            else
                                echo "limon: host_color must be auto, off, or 0-255" >&2
                            fi
                            ;;
                    esac
                    ;;
                env_banner=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_ENV_BANNER="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: env_banner must be 0 or 1" >&2 ;;
                    esac
                    ;;
                show_root=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_SHOW_ROOT="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: show_root must be 0 or 1" >&2 ;;
                    esac
                    ;;
                show_sudo=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_SHOW_SUDO="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: show_sudo must be 0 or 1" >&2 ;;
                    esac
                    ;;
                k8s=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_K8S="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: k8s must be 0 or 1" >&2 ;;
                    esac
                    ;;
                cloud=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_CLOUD="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: cloud must be 0 or 1" >&2 ;;
                    esac
                    ;;
                show_exit=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_SHOW_EXIT="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: show_exit must be 0 or 1" >&2 ;;
                    esac
                    ;;
                exit_hints=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_EXIT_HINTS="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: exit_hints must be 0 or 1" >&2 ;;
                    esac
                    ;;
                clock=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_SHOW_CLOCK="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: clock must be 0 or 1" >&2 ;;
                    esac
                    ;;
                metrics=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_METRICS="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: metrics must be 0 or 1" >&2 ;;
                    esac
                    ;;
                autosuggest=*)
                    case "${CONFIG_ARG#*=}" in
                        0|1) LIMON_AUTOSUGGEST="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: autosuggest must be 0 or 1" >&2 ;;
                    esac
                    ;;
                autosuggest_delay=*)
                    if [[ "${CONFIG_ARG#*=}" =~ ^[0-9]+$ ]] && (( ${CONFIG_ARG#*=} <= 2000 )); then
                        LIMON_AUTOSUGGEST_DELAY="${CONFIG_ARG#*=}"
                        config_ok=1
                    else
                        echo "limon: autosuggest_delay must be an integer from 0 to 2000 milliseconds" >&2
                    fi
                    ;;
                autosuggest_color=*)
                    case "${CONFIG_ARG#*=}" in
                        auto) LIMON_AUTOSUGGEST_COLOR=auto; config_ok=1 ;;
                        *)
                            if [[ "${CONFIG_ARG#*=}" =~ ^[0-9]+$ ]] && (( ${CONFIG_ARG#*=} <= 255 )); then
                                LIMON_AUTOSUGGEST_COLOR="${CONFIG_ARG#*=}"
                                config_ok=1
                            else
                                echo "limon: autosuggest_color must be auto or 0-255" >&2
                            fi
                            ;;
                    esac
                    ;;
                *)
                    echo "limon: unknown config option '$CONFIG_ARG'" >&2
                    echo "Usage: limon config ... host_color=auto|off|N env_banner=0|1 show_root=0|1 show_sudo=0|1 k8s=0|1 cloud=0|1" >&2
                    ;;
            esac
            if [[ "$config_ok" -eq 1 ]]; then
                mapfile -t _limon_flags < <(_limon_conf_flags)
                _limon_write_config "$saved_theme" "${_limon_flags[@]}"
                # These stay shell variables rather than environment variables: the prompt
                # renderer runs in this shell via PROMPT_COMMAND, and subshells inherit
                # shell variables anyway, so exporting them only pollutes the environment
                # of every child process.
                if _limon_is_active && [[ "$CONFIG_ARG" == autosuggest* ]]; then
                    # Re-run provider selection so autosuggestion changes take
                    # effect immediately. A loaded bundled editor stays resident.
                    # shellcheck source=limon.sh
                    source "$SCRIPT_DIR/limon.sh" on "$saved_theme"
                elif _limon_is_active; then
                    unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
                          __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
                          __LIMON_GIT_CACHE_DETACHED __LIMON_STASH_CACHE_SEC __LIMON_STASH_CACHE
                    _limon_invalidate_theme_cache
                    limon_runner
                fi
            fi
        fi
        ;;
    colors)
        echo "Limon 256-Color Palette:"
        echo "Usage in themes: col_git='\[\e[38;5;214m\]' (This is color 214)"
        echo ""
        for i in {0..255}; do
            printf "\x1b[38;5;${i}m%3d\x1b[0m " "$i"
            if (( (i + 1) % 16 == 0 )); then echo; fi
        done
        echo ""
        ;;
    version|--version|-v)
        printf 'limon %s\n' "$LIMON_VERSION"
        if _limon_is_git_install; then
            rev="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
            if [[ -n "$rev" ]]; then
                printf 'commit %s\n' "$rev"
            fi
        fi
        ;;
    help|"")
        echo "
limon - Optimized Bash Prompt

Usage:
    limon on [theme]     Enable Limon (optionally set theme)
    limon off            Restore default prompt
    limon reload         Reload theme and config
    limon upgrade [chan] Update Limon (optionally switch channel: stable|beta|dev)
    limon uninstall      Remove Limon (prompts to keep or delete config)
    limon status         Show current state
    limon health         Run install and prompt diagnostics
    limon bench [N]      Benchmark prompt render time (default N=100)
    limon bench --breakdown  Per-segment render timings
    limon themes         List available themes
    limon edit [theme]   Open theme in \$EDITOR (creates ~/.config/limon/themes/ copy)
    limon preview <theme> Show sample prompt without switching
    limon config KEY=VAL Set timer, git, autosuggestion, safety, and rendering options
    limon colors         Show ANSI color codes
    limon version        Show the installed Limon version
    limon help           Show this help

Auto-update:
    limon config autoupdate=off     Never check for updates (default)
    limon config autoupdate=notify  Check daily, notify when an update exists
    limon config autoupdate=on       Check daily, auto-install updates if possible

Update channels (which branch upgrades track):
    limon upgrade               Update on the current channel
    limon upgrade stable        Switch to stable (branch: master) and update [default]
    limon upgrade beta          Switch to beta (newest features, may be unstable)
    limon upgrade dev           Switch to dev (active development, expect breakage)
    limon config channel=beta   Set the channel without upgrading right now

Safe rendering:
    limon config ascii=1            Use ASCII symbols (# > ^ v) instead of Unicode
    limon config max_path=40        Truncate long paths in the prompt
    theme_max_path=N                Per-theme path limit in .theme files
    Colors auto-disable when TERM=dumb or output is not a TTY

Identity & safety:
    limon config host_color=off     Use theme host color instead (default)
    limon config host_color=auto    Hash hostname to a distinct color
    export LIMON_ENV=prod           Set environment label (prod/staging/dev)
    limon config env_banner=1       Show colored PROD/STAGING banner when LIMON_ENV is set
    limon config show_root=1        Show ROOT warning when running as root
    limon config show_root=0        Hide ROOT warning (default)
    limon config show_sudo=1        Show (sudo) when cached sudo credentials exist (default)
    limon config cloud=1            Show AWS_PROFILE when set
    limon config k8s=1              Show kubectl current-context (cached 2s)

Git clarity:
    limon config git=full           Branch, dirty (?), ahead/behind, stash, operations (default)
    limon config git=verbose        Detailed +N staged, ~N modified, ?N untracked counts
    limon config git=lite           Branch name only (faster)
    limon config git=off            Hide git segment

Exit codes:
    limon config show_exit=1        Show exit code on failure (e.g. x127 $)
    limon config exit_hints=1       Add hints like x130(SIGINT) when show_exit=1

Prompt extras:
    limon config clock=1            Show HH:MM before the command timer (default off)

Ghost autosuggestions:
    limon config autosuggest=1      Enable inline suggestions (default)
    limon config autosuggest=0      Disable ghost suggestions
    limon config autosuggest_delay=100  Delay in milliseconds (0-2000)
    limon config autosuggest_color=245  Ghost text color (auto or 0-255)
    Right/End accepts all; Ctrl+Right accepts one word; Tab completes normally

Diagnostics:
    limon health                    Check bash, colors, git, theme, and prompt state

Performance metrics:
    limon bench                     Measure average prompt render time (100 runs)
    limon bench 500                 Run more iterations for a steadier average
    limon bench --breakdown         Show which segment costs what
    limon config metrics=1          Record live render time each prompt (shown in status)
    limon config metrics=0          Stop recording live render time (default)
    (render time is wall-clock; needs bash 5+ or GNU date for sub-ms precision)

Config file: $LIMON_CONF
  Example: neon -env_banner=1 -host_color=auto -show_root=1 -cloud=1 -k8s=1
"
        ;;
esac
