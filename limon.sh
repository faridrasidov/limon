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

LIMON_VERSION="1.0.0"

# --- 1. Self-Healing & Safety ---
if [[ "${DEFAULT_PROMPT_COMMAND:-}" == *"not found"* ]] || \
   [[ "${DEFAULT_PROMPT_COMMAND:-}" == *"limon_runner"* ]]; then
    DEFAULT_PROMPT_COMMAND=""
fi

if [ -z "${DEFAULT_PS1}" ]; then
    DEFAULT_PS1="${PS1}"
    export DEFAULT_PS1
fi

if [[ -z "${PROMPT_COMMAND}" ]]; then
    DEFAULT_PROMPT_COMMAND=""
else
    if [[ "$PROMPT_COMMAND" != *"limon_runner"* ]]; then
        DEFAULT_PROMPT_COMMAND="${PROMPT_COMMAND}"
    fi
fi
export DEFAULT_PROMPT_COMMAND

# --- 2. Path & Config Setup ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ -n "$XDG_CONFIG_HOME" ]]; then
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
LIMON_HOST_COLOR=auto
LIMON_ENV_BANNER=0
LIMON_SHOW_ROOT=1
LIMON_SHOW_SUDO=1
LIMON_K8S=0
LIMON_CLOUD=0
LIMON_SHOW_EXIT=0
LIMON_EXIT_HINTS=0
LIMON_SHOW_CLOCK=0
LIMON_METRICS=0

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
    LIMON_HOST_COLOR=auto
    LIMON_ENV_BANNER=0
    LIMON_SHOW_ROOT=1
    LIMON_SHOW_SUDO=1
    LIMON_K8S=0
    LIMON_CLOUD=0
    LIMON_SHOW_EXIT=0
    LIMON_EXIT_HINTS=0
    LIMON_SHOW_CLOCK=0
    LIMON_METRICS=0

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
    [[ "$LIMON_HOST_COLOR" != "auto" ]] && flags+=("-host_color=$LIMON_HOST_COLOR")
    [[ "$LIMON_ENV_BANNER" != "0" ]] && flags+=("-env_banner=$LIMON_ENV_BANNER")
    [[ "$LIMON_SHOW_ROOT" != "1" ]] && flags+=("-show_root=$LIMON_SHOW_ROOT")
    [[ "$LIMON_SHOW_SUDO" != "1" ]] && flags+=("-show_sudo=$LIMON_SHOW_SUDO")
    [[ "$LIMON_K8S" != "0" ]] && flags+=("-k8s=$LIMON_K8S")
    [[ "$LIMON_CLOUD" != "0" ]] && flags+=("-cloud=$LIMON_CLOUD")
    [[ "$LIMON_SHOW_EXIT" != "0" ]] && flags+=("-show_exit=$LIMON_SHOW_EXIT")
    [[ "$LIMON_EXIT_HINTS" != "0" ]] && flags+=("-exit_hints=$LIMON_EXIT_HINTS")
    [[ "$LIMON_SHOW_CLOCK" != "0" ]] && flags+=("-clock=$LIMON_SHOW_CLOCK")
    [[ "$LIMON_METRICS" != "0" ]] && flags+=("-metrics=$LIMON_METRICS")
    printf '%s\n' "${flags[@]}"
}

_limon_is_active() {
    [[ "${PROMPT_COMMAND:-}" == *"limon_runner"* ]]
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

    if [[ "${BASH_VERSINFO[0]:-0}" -ge 4 ]]; then
        _limon_health_msg OK "bash ${BASH_VERSION}"
    else
        _limon_health_msg FAIL "bash ${BASH_VERSION} (4.0+ required)"
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
        if [[ "${PROMPT_COMMAND:-}" == *"limon_runner"* ]]; then
            _limon_health_msg OK "limon_runner hooked in PROMPT_COMMAND"
        else
            _limon_health_msg FAIL "prompt active but limon_runner missing from PROMPT_COMMAND"
            ((issues++)) || true
        fi
    else
        _limon_health_msg OK "prompt off"
        if [[ "${PROMPT_COMMAND:-}" == *"limon_runner"* ]]; then
            _limon_health_msg FAIL "limon_runner still in PROMPT_COMMAND (run 'limon off')"
            ((issues++)) || true
        else
            _limon_health_msg OK "clean PROMPT_COMMAND (no limon_runner)"
        fi
    fi

    if trap -p DEBUG 2>/dev/null | grep -q .; then
        _limon_health_msg WARN "DEBUG trap is set (limon does not use DEBUG)"
        ((warnings++)) || true
    else
        _limon_health_msg OK "no DEBUG trap"
    fi

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
    fi

    local hp_theme="${LIMON_THEME_ARG:-${saved_theme:-default}}" hp_ps1="$PS1" hp_t0 hp_t1 hp_n=20 hp_i
    _limon_clock_us; hp_t0="$__LIMON_T"
    if [[ -n "$hp_t0" ]]; then
        for (( hp_i = 0; hp_i < hp_n; hp_i++ )); do main "$hp_theme" >/dev/null 2>&1; done
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
    echo "$s"
}

# --- Phase 8: Exit-code clarity ---
_limon_exit_hint() {
    local code="$1"
    case "$code" in
        1) echo "error" ;;
        2) echo "builtin" ;;
        126) echo "not executable" ;;
        127) echo "not found" ;;
        130) echo "SIGINT" ;;
        137) echo "SIGKILL" ;;
        143) echo "SIGTERM" ;;
        1[2-9][0-9]) echo "signal$((code - 128))" ;;
        *) return 1 ;;
    esac
}

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
            local hint
            hint="$(_limon_exit_hint "$last_exit" 2>/dev/null || true)"
            [[ -n "$hint" ]] && exit_label+="(${hint})"
        fi
        if [[ -n "$theme_symbol_prefix" ]]; then
            symbol_str="${symbol_str}${theme_symbol_prefix}${exit_label} ${prompt_char} ${c_reset}"
        else
            symbol_str="${symbol_str}${exit_label} ${prompt_char} ${c_reset}"
        fi
        echo -n "$symbol_str"
        return
    fi

    [[ -n "$theme_symbol_prefix" ]] && symbol_str="${symbol_str}${theme_symbol_prefix}"
    symbol_str="${symbol_str}${prompt_char} ${c_reset}"
    echo -n "$symbol_str"
}

# --- Phase 6: Identity & safety helpers ---
_limon_host_color_code() {
    local mode="${LIMON_HOST_COLOR:-auto}"
    local host="${HOSTNAME:-$(hostname 2>/dev/null)}"

    if [[ "$mode" == "off" || "$mode" == "0" ]]; then
        return 1
    fi

    if [[ "$mode" == "auto" ]]; then
        local hash=0 i c
        for ((i = 0; i < ${#host}; i++)); do
            c=$(printf '%d' "'${host:$i:1}")
            hash=$(( (hash * 31 + c) % 216 ))
        done
        echo $(( 32 + hash % 200 ))
        return 0
    fi

    if [[ "$mode" =~ ^[0-9]+$ ]]; then
        echo "$mode"
        return 0
    fi

    return 1
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

_limon_k8s_label() {
    [[ "${LIMON_K8S:-0}" != "1" ]] && return 1

    if [[ -n "${KUBE_PS1_CONTEXT:-}" ]]; then
        echo "(k8s:$KUBE_PS1_CONTEXT)"
        return 0
    fi

    if [[ $((SECONDS - ${__LIMON_K8S_CACHE_SEC:-0})) -lt 2 && -n "${__LIMON_K8S_CACHE_CTX:-}" ]]; then
        echo "(k8s:$__LIMON_K8S_CACHE_CTX)"
        return 0
    fi

    if ! command -v kubectl >/dev/null 2>&1; then
        return 1
    fi

    local ctx
    ctx="$(kubectl config current-context 2>/dev/null)" || return 1
    __LIMON_K8S_CACHE_CTX="$ctx"
    __LIMON_K8S_CACHE_SEC=$SECONDS
    echo "(k8s:$ctx)"
}

_limon_safety_prefix() {
    local c_reset="$1"
    local col_err="$2"
    local prefix=""

    if [[ "${EUID}" -eq 0 && "${LIMON_SHOW_ROOT:-1}" == "1" ]]; then
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

    local k8s_label
    k8s_label="$(_limon_k8s_label 2>/dev/null || true)"
    if [[ -n "$k8s_label" ]]; then
        prefix+="${c_reset}${k8s_label} "
    fi

    echo -n "$prefix"
}

_limon_display_path() {
    local max="$1"
    local path="$PWD"

    if [[ -n "$HOME" ]]; then
        if [[ "$path" == "$HOME" ]]; then
            path="~"
        elif [[ "$path" == "$HOME/"* ]]; then
            path="~/${path#$HOME/}"
        fi
    fi

    if [[ "$max" =~ ^[0-9]+$ && "$max" -gt 0 && ${#path} -gt "$max" ]]; then
        local tail="${path##*/}"
        [[ -z "$tail" ]] && tail="/"
        if [[ "$path" == ~* ]]; then
            path="~/…/${tail}"
        elif [[ "$path" == /* ]]; then
            path="/…/${tail}"
        else
            path="…/${tail}"
        fi
        while [[ ${#path} -gt "$max" && ${#tail} -gt 1 ]]; do
            tail="${tail#*/}"
            [[ "$path" == ~* ]] && path="~/…/${tail}" || path="/…/${tail}"
        done
        [[ ${#path} -gt "$max" ]] && path="…${tail: -$((max - 1))}"
    fi

    echo "$path"
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

# Format integer microseconds as "N.NNN ms".
_limon_fmt_ms() {
    local us="$1"
    (( us < 0 )) && us=0
    printf '%d.%03d ms' $(( us / 1000 )) $(( us % 1000 ))
}

# Benchmark prompt rendering: limon bench [iterations]
_limon_do_bench() {
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
        main "$theme" >/dev/null 2>&1
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
        echo "limon: not a git installation ($SCRIPT_DIR)." >&2
        echo "limon: to enable upgrades, reinstall from a clone:" >&2
        echo "limon:   git clone https://github.com/faridrasidov/limon" >&2
        echo "limon:   cd limon && bash install.sh   # add --system for all users" >&2
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
    main "$theme_name"
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

# Restore the current shell's prompt and forget Limon state (used by off/uninstall).
_limon_restore_session() {
    export PS1="$DEFAULT_PS1"
    PROMPT_COMMAND="${DEFAULT_PROMPT_COMMAND:-}"
    trap - DEBUG 2>/dev/null || true
    unset timer LAST_EXIT_CODE 2>/dev/null || true
    unset __LIMON_CMD_START __LIMON_CMD_ELAPSED \
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

export LIMON_TIMER_THRESHOLD LIMON_GIT_MODE LIMON_SHOW_HOST LIMON_SHOW_SSH LIMON_AUTOUPDATE \
       LIMON_CHANNEL LIMON_ASCII LIMON_MAX_PATH LIMON_HOST_COLOR LIMON_ENV_BANNER LIMON_SHOW_ROOT \
       LIMON_SHOW_SUDO LIMON_K8S LIMON_CLOUD LIMON_SHOW_EXIT LIMON_EXIT_HINTS LIMON_SHOW_CLOCK LIMON_METRICS

# --- 5. Git Info (single call + short cache) ---
_limon_git_op_state() {
    local git_dir
    git_dir="$(git --no-optional-locks rev-parse --git-dir 2>/dev/null)" || return 1
    if [[ -f "$git_dir/MERGE_HEAD" ]]; then
        echo "MERGING"
    elif [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
        echo "REBASING"
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
        echo "CHERRY-PICK"
    else
        return 1
    fi
}

_limon_git_stash_count() {
    if [[ $((SECONDS - ${__LIMON_STASH_CACHE_SEC:-0})) -lt 2 && "${__LIMON_STASH_CACHE:-}" =~ ^[0-9]+$ ]]; then
        echo "$__LIMON_STASH_CACHE"
        return
    fi
    local count
    count="$(git --no-optional-locks stash list 2>/dev/null | wc -l | tr -d ' ')"
    __LIMON_STASH_CACHE="${count:-0}"
    __LIMON_STASH_CACHE_SEC=$SECONDS
    echo "$__LIMON_STASH_CACHE"
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
    local op_state marks=""

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

        op_state="$(_limon_git_op_state 2>/dev/null || true)"
        [[ -n "$op_state" ]] && marks+=" {$op_state}"

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
        stash_n="$(_limon_git_stash_count 2>/dev/null || echo 0)"
        [[ "${stash_n:-0}" -gt 0 ]] && marks+=" ≡${stash_n}"

        [[ $push_count -gt 0 ]] && marks+=" ↑$push_count"
        [[ $pull_count -gt 0 ]] && marks+=" ↓$pull_count"

        __LIMON_GIT_MARKS="$marks"

        _limon_init_symbols
        if [[ "${LIMON_ASCII:-0}" == "1" ]]; then
            __LIMON_GIT_MARKS="$(_limon_ascii_text "$__LIMON_GIT_MARKS")"
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
main() {
    local last_exit=$LAST_EXIT_CODE
    local theme_name="${1:-default}"

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
        source "$theme_file"
    fi

    local c_reset='\[\e[m\]'
    local c_gray='\[\e[38;5;240m\]'

    if ! _limon_use_color; then
        col_ok='' col_err='' col_git='' col_dir='' col_host='' col_time=''
        c_reset='' c_gray=''
    fi

    _limon_init_symbols
    if [[ "${LIMON_ASCII:-0}" == "1" ]]; then
        theme_symbol_prefix="$(_limon_ascii_text "$theme_symbol_prefix")"
    fi

    local host_color_code
    if _limon_use_color; then
        if host_color_code="$(_limon_host_color_code 2>/dev/null)"; then
            col_host='\[\e[38;5;'${host_color_code}'m\]'
        fi
    fi

    local safety_str
    safety_str="$(_limon_safety_prefix "$c_reset" "$col_err")"

    local elapsed_str=""
    if [[ ${__LIMON_CMD_ELAPSED:-0} -ge ${LIMON_TIMER_THRESHOLD:-2} ]]; then
        local elapsed=$__LIMON_CMD_ELAPSED
        local min=$((elapsed / 60))
        local sec=$((elapsed % 60))
        [[ $min -gt 0 ]] && elapsed_str=" ${min}m ${sec}s" || elapsed_str=" ${sec}s"
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
    [[ -n "$VIRTUAL_ENV" ]] && env_parts+=("(venv)")
    [[ -n "$CONDA_DEFAULT_ENV" ]] && env_parts+=("(conda:$CONDA_DEFAULT_ENV)")
    [[ -n "$DOCKER_MACHINE_NAME" ]] && env_parts+=("(dkr:$DOCKER_MACHINE_NAME)")
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
        path_display="$(_limon_display_path "$path_max")"
    fi

    local dir_str=""
    if [[ -n "$path_display" ]]; then
        dir_str="$dir_color${path_display}${lock_icon}"
    else
        dir_str="$dir_color\w$lock_icon"
    fi

    local time_display=""
    if [[ "${LIMON_SHOW_CLOCK:-0}" == "1" ]]; then
        time_display+="$col_time$(date +%H:%M) "
    fi
    [[ -n "$elapsed_str" ]] && time_display+="$col_time$elapsed_str "

    local jobs_str=""
    local job_count
    job_count="$(jobs -rp 2>/dev/null | wc -l | tr -d ' ')"
    [[ "${job_count:-0}" -gt 0 ]] && jobs_str="[$job_count] "

    local symbol_str
    symbol_str="$(_limon_prompt_symbol "$last_exit" "$col_ok" "$col_err" "$c_reset" "$theme_symbol_prefix")"

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
export -f main

# --- 7. Runner ---
limon_runner() {
    LAST_EXIT_CODE=$?
    if [[ -n "${__LIMON_CMD_START:-}" ]]; then
        __LIMON_CMD_ELAPSED=$((SECONDS - __LIMON_CMD_START))
    else
        __LIMON_CMD_ELAPSED=0
    fi
    __LIMON_CMD_START=$SECONDS
    if [[ "${LIMON_METRICS:-0}" == "1" ]]; then
        local __limon_a __limon_b
        _limon_clock_us; __limon_a="$__LIMON_T"
        main "$LIMON_THEME_ARG"
        _limon_clock_us; __limon_b="$__LIMON_T"
        if [[ -n "$__limon_a" && -n "$__limon_b" ]]; then
            __LIMON_RENDER_US=$(( __limon_b - __limon_a ))
            (( __LIMON_RENDER_US < 0 )) && __LIMON_RENDER_US=0
            export __LIMON_RENDER_US
        fi
    else
        main "$LIMON_THEME_ARG"
    fi
}
export -f limon_runner
export -f _limon_clock_us

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
        __LIMON_CMD_START=$SECONDS
        PROMPT_COMMAND="limon_runner${DEFAULT_PROMPT_COMMAND:+; $DEFAULT_PROMPT_COMMAND}"
        LAST_EXIT_CODE=${LAST_EXIT_CODE:-0}
        __LIMON_CMD_ELAPSED=0
        limon_runner
        _limon_load_hints
        _limon_maybe_autoupdate
        ;;
    upgrade|update)
        _limon_do_upgrade "${1:-}"
        ;;
    uninstall)
        _limon_do_uninstall "$@"
        ;;
    off)
        _limon_restore_session
        ;;
    reload)
        if ! _limon_is_active; then
            echo "limon: not active (run 'limon on' first)" >&2
        else
            unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
                  __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
                  __LIMON_GIT_CACHE_DETACHED __LIMON_STASH_CACHE_SEC __LIMON_STASH_CACHE
            _limon_load_config
            export LIMON_TIMER_THRESHOLD LIMON_GIT_MODE LIMON_SHOW_HOST LIMON_SHOW_SSH LIMON_AUTOUPDATE \
                   LIMON_CHANNEL LIMON_ASCII LIMON_MAX_PATH LIMON_HOST_COLOR LIMON_ENV_BANNER LIMON_SHOW_ROOT \
                   LIMON_SHOW_SUDO LIMON_K8S LIMON_CLOUD LIMON_SHOW_EXIT LIMON_EXIT_HINTS LIMON_SHOW_CLOCK LIMON_METRICS
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
            echo "Install: $SCRIPT_DIR (not a git install — 'limon upgrade' unavailable)"
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
        _limon_do_bench "${1:-}"
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
            echo "Usage: limon config timer_threshold=N|git=full|lite|off|show_host=0|1|show_ssh=0|1|autoupdate=off|notify|on|channel=stable|beta|dev|ascii=0|1|max_path=N|host_color=auto|off|N|env_banner=0|1|show_root=0|1|show_sudo=0|1|k8s=0|1|cloud=0|1|show_exit=0|1|exit_hints=0|1|clock=0|1|metrics=0|1"
            echo "Current: timer_threshold=$LIMON_TIMER_THRESHOLD git=$LIMON_GIT_MODE show_host=$LIMON_SHOW_HOST show_ssh=$LIMON_SHOW_SSH autoupdate=$LIMON_AUTOUPDATE channel=$LIMON_CHANNEL ascii=$LIMON_ASCII max_path=$LIMON_MAX_PATH"
            echo "         host_color=$LIMON_HOST_COLOR env_banner=$LIMON_ENV_BANNER show_root=$LIMON_SHOW_ROOT show_sudo=$LIMON_SHOW_SUDO k8s=$LIMON_K8S cloud=$LIMON_CLOUD show_exit=$LIMON_SHOW_EXIT exit_hints=$LIMON_EXIT_HINTS clock=$LIMON_SHOW_CLOCK metrics=$LIMON_METRICS"
        else
            config_ok=0
            case "$CONFIG_ARG" in
                timer_threshold=*) LIMON_TIMER_THRESHOLD="${CONFIG_ARG#*=}"; config_ok=1 ;;
                git=*)
                    case "${CONFIG_ARG#*=}" in
                        full|lite|verbose|off) LIMON_GIT_MODE="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: git must be full, lite, verbose, or off" >&2 ;;
                    esac
                    ;;
                show_host=*) LIMON_SHOW_HOST="${CONFIG_ARG#*=}"; config_ok=1 ;;
                show_ssh=*) LIMON_SHOW_SSH="${CONFIG_ARG#*=}"; config_ok=1 ;;
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
                *)
                    echo "limon: unknown config option '$CONFIG_ARG'" >&2
                    echo "Usage: limon config ... host_color=auto|off|N env_banner=0|1 show_root=0|1 show_sudo=0|1 k8s=0|1 cloud=0|1" >&2
                    ;;
            esac
            if [[ "$config_ok" -eq 1 ]]; then
                mapfile -t _limon_flags < <(_limon_conf_flags)
                _limon_write_config "$saved_theme" "${_limon_flags[@]}"
                export LIMON_TIMER_THRESHOLD LIMON_GIT_MODE LIMON_SHOW_HOST LIMON_SHOW_SSH LIMON_AUTOUPDATE \
                       LIMON_CHANNEL LIMON_ASCII LIMON_MAX_PATH LIMON_HOST_COLOR LIMON_ENV_BANNER LIMON_SHOW_ROOT \
                       LIMON_SHOW_SUDO LIMON_K8S LIMON_CLOUD LIMON_SHOW_EXIT LIMON_EXIT_HINTS LIMON_SHOW_CLOCK LIMON_METRICS
                if _limon_is_active; then
                    unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC __LIMON_GIT_CACHE_ASCII \
                          __LIMON_GIT_CACHE_MODE __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS \
                          __LIMON_GIT_CACHE_DETACHED __LIMON_STASH_CACHE_SEC __LIMON_STASH_CACHE
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
    limon themes         List available themes
    limon edit [theme]   Open theme in \$EDITOR (creates ~/.config/limon/themes/ copy)
    limon preview <theme> Show sample prompt without switching
    limon config KEY=VAL Set timer, git, host, safety, and rendering options
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
    limon config host_color=auto    Hash hostname to a distinct color (default)
    limon config host_color=off     Use theme host color instead
    export LIMON_ENV=prod           Set environment label (prod/staging/dev)
    limon config env_banner=1       Show colored PROD/STAGING banner when LIMON_ENV is set
    limon config show_root=1        Show ROOT warning when running as root (default)
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

Diagnostics:
    limon health                    Check bash, colors, git, theme, and prompt state

Performance metrics:
    limon bench                     Measure average prompt render time (100 runs)
    limon bench 500                 Run more iterations for a steadier average
    limon config metrics=1          Record live render time each prompt (shown in status)
    limon config metrics=0          Stop recording live render time (default)
    (render time is wall-clock; needs bash 5+ or GNU date for sub-ms precision)

Config file: $LIMON_CONF
  Example: neon -env_banner=1 -host_color=auto -cloud=1 -k8s=1
"
        ;;
esac
