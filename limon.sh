#!/usr/bin/env bash

# limon - Optimized Bash Prompt
# Features: 256-Color ANSI Support, Color Picker, Silent Default, Modular Themes

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

    if [[ -f "$LIMON_CONF" ]]; then
        read -r -a conf_parts < "$LIMON_CONF"
        for part in "${conf_parts[@]}"; do
            case "$part" in
                -timer_threshold=*) LIMON_TIMER_THRESHOLD="${part#*=}" ;;
                -git=*) LIMON_GIT_MODE="${part#*=}" ;;
                -show_host=*) LIMON_SHOW_HOST="${part#*=}" ;;
                -show_ssh=*) LIMON_SHOW_SSH="${part#*=}" ;;
                -autoupdate=*) LIMON_AUTOUPDATE="${part#*=}" ;;
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
    printf '%s\n' "${flags[@]}"
}

_limon_is_active() {
    [[ "${PROMPT_COMMAND:-}" == *"limon_runner"* ]]
}

# --- Auto-update helpers ---
_limon_is_git_install() {
    command -v git >/dev/null 2>&1 && [[ -d "$SCRIPT_DIR/.git" ]]
}

# Quietly fetch and compare HEAD with upstream. Used in the background.
# Marks an update as available (or auto-pulls when autoupdate=on).
_limon_background_update_check() {
    _limon_is_git_install || return 0
    git -C "$SCRIPT_DIR" --no-optional-locks fetch --quiet 2>/dev/null || return 0

    local local_rev remote_rev
    local_rev="$(git -C "$SCRIPT_DIR" rev-parse @ 2>/dev/null)" || return 0
    remote_rev="$(git -C "$SCRIPT_DIR" rev-parse '@{u}' 2>/dev/null)" || return 0
    [[ -z "$remote_rev" || "$local_rev" == "$remote_rev" ]] && { rm -f "$LIMON_UPDATE_FLAG"; return 0; }

    if [[ "$LIMON_AUTOUPDATE" == "on" && -w "$SCRIPT_DIR/.git" ]]; then
        if git -C "$SCRIPT_DIR" pull --quiet --ff-only 2>/dev/null; then
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

# Manual, foreground updater for `limon upgrade`.
_limon_do_upgrade() {
    if ! command -v git >/dev/null 2>&1; then
        echo "limon: git is required to upgrade." >&2
        return 1
    fi
    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        echo "limon: not a git installation ($SCRIPT_DIR)." >&2
        echo "limon: reinstall via 'git clone' to enable upgrades." >&2
        return 1
    fi
    if [[ ! -w "$SCRIPT_DIR/.git" ]]; then
        echo "limon: no write permission for $SCRIPT_DIR." >&2
        echo "limon: try: sudo git -C \"$SCRIPT_DIR\" pull --ff-only" >&2
        return 1
    fi

    echo "limon: checking for updates in $SCRIPT_DIR ..."
    git -C "$SCRIPT_DIR" --no-optional-locks fetch --quiet 2>/dev/null

    local local_rev remote_rev
    local_rev="$(git -C "$SCRIPT_DIR" rev-parse @ 2>/dev/null)"
    remote_rev="$(git -C "$SCRIPT_DIR" rev-parse '@{u}' 2>/dev/null)"
    if [[ -n "$remote_rev" && "$local_rev" == "$remote_rev" ]]; then
        echo "limon: already up to date."
        rm -f "$LIMON_UPDATE_FLAG"
        return 0
    fi

    if git -C "$SCRIPT_DIR" pull --ff-only; then
        rm -f "$LIMON_UPDATE_FLAG"
        echo "limon: updated successfully."
        echo "limon: run 'limon on' or open a new terminal to load the new version."
    else
        echo "limon: update failed (local changes or non-fast-forward history)." >&2
        return 1
    fi
}

# Restore the current shell's prompt and forget Limon state (used by off/uninstall).
_limon_restore_session() {
    export PS1="$DEFAULT_PS1"
    PROMPT_COMMAND="$DEFAULT_PROMPT_COMMAND"
    unset __LIMON_CMD_START __LIMON_CMD_ELAPSED \
          __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC \
          __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS
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
    THEME_NAME="$saved_theme"
fi

# --- 4. Save State ---
if [[ "$SUBCOMMAND" == "on" ]]; then
    mapfile -t _limon_flags < <(_limon_conf_flags)
    _limon_write_config "$THEME_NAME" "${_limon_flags[@]}"
    if ! _limon_theme_exists "$THEME_NAME"; then
        echo "limon: theme '$THEME_NAME' not found, using built-in defaults" >&2
    fi
fi

export LIMON_TIMER_THRESHOLD LIMON_GIT_MODE LIMON_SHOW_HOST LIMON_SHOW_SSH LIMON_AUTOUPDATE

# --- 5. Git Info (single call + short cache) ---
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

# Sets: __LIMON_GIT_BRANCH, __LIMON_GIT_MARKS, __LIMON_GIT_IN_REPO
_limon_git_info() {
    __LIMON_GIT_BRANCH=""
    __LIMON_GIT_MARKS=""
    __LIMON_GIT_IN_REPO=0

    case "${LIMON_GIT_MODE:-full}" in
        off) return ;;
        lite) _limon_git_lite; return ;;
    esac

    if ! command -v git >/dev/null 2>&1; then
        return
    fi

    if [[ "${__LIMON_GIT_CACHE_PWD:-}" == "$PWD" && \
          $((SECONDS - ${__LIMON_GIT_CACHE_SEC:-0})) -lt 1 ]]; then
        __LIMON_GIT_BRANCH="$__LIMON_GIT_CACHE_BRANCH"
        __LIMON_GIT_MARKS="$__LIMON_GIT_CACHE_MARKS"
        __LIMON_GIT_IN_REPO=1
        return
    fi

    local line marks="" push_count=0 pull_count=0 got_branch=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^## ]]; then
            got_branch=1
            if [[ "$line" =~ ^##\ No\ commits\ yet\ on\ (.+) ]]; then
                __LIMON_GIT_BRANCH="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^##\ (HEAD\ \(no\ branch\)) ]]; then
                __LIMON_GIT_BRANCH="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^##\ ([^.[:space:]]+) ]]; then
                __LIMON_GIT_BRANCH="${BASH_REMATCH[1]}"
            fi
            [[ "$line" =~ ahead\ ([0-9]+) ]] && push_count=${BASH_REMATCH[1]}
            [[ "$line" =~ behind\ ([0-9]+) ]] && pull_count=${BASH_REMATCH[1]}
        else
            if [[ "$line" == \?\?* ]]; then marks+=" ?"; else marks+=" (@)"; fi
        fi
    done < <(git --no-optional-locks status --porcelain --branch 2>/dev/null)

    if [[ $got_branch -eq 1 ]]; then
        __LIMON_GIT_IN_REPO=1
        [[ "$marks" == *"(@)"* ]] && __LIMON_GIT_MARKS+=" (@)"
        [[ "$marks" == *"?"* ]] && __LIMON_GIT_MARKS+=" ?"
        [[ $push_count -gt 0 ]] && __LIMON_GIT_MARKS+=" ↑$push_count"
        [[ $pull_count -gt 0 ]] && __LIMON_GIT_MARKS+=" ↓$pull_count"

        __LIMON_GIT_CACHE_PWD="$PWD"
        __LIMON_GIT_CACHE_SEC=$SECONDS
        __LIMON_GIT_CACHE_BRANCH="$__LIMON_GIT_BRANCH"
        __LIMON_GIT_CACHE_MARKS="$__LIMON_GIT_MARKS"
    else
        unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC \
              __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS
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

    local theme_file
    theme_file="$(_limon_resolve_theme_file "$theme_name" 2>/dev/null || true)"
    [[ -n "$theme_file" ]] && source "$theme_file"

    local elapsed_str=""
    if [[ ${__LIMON_CMD_ELAPSED:-0} -ge ${LIMON_TIMER_THRESHOLD:-2} ]]; then
        local elapsed=$__LIMON_CMD_ELAPSED
        local min=$((elapsed / 60))
        local sec=$((elapsed % 60))
        [[ $min -gt 0 ]] && elapsed_str=" ${min}m ${sec}s" || elapsed_str=" ${sec}s"
    fi

    local c_reset='\[\e[m\]'
    local c_gray='\[\e[38;5;240m\]'

    local git_str=""
    _limon_git_info
    if [[ ${__LIMON_GIT_IN_REPO:-0} -eq 1 ]]; then
        if [[ "$theme_multiline" -eq 1 ]]; then
            git_str="$col_git$__LIMON_GIT_MARKS ($__LIMON_GIT_BRANCH)"
        else
            git_str="$col_git$__LIMON_GIT_MARKS [$__LIMON_GIT_BRANCH]"
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

    if [[ ! -w . ]]; then
        lock_icon=" 🔒"
        [[ "${EUID}" -ne 0 ]] && dir_color=$c_gray
    fi
    if [[ "${EUID}" -eq 0 && "$PWD" != /root* && "$PWD" != /home* && "$PWD" == /* ]]; then
        dir_color=$col_err
    fi
    local dir_str="$dir_color\w$lock_icon"

    local time_display=""
    [[ -n "$elapsed_str" ]] && time_display="$col_time$elapsed_str "

    local jobs_str=""
    local job_count
    job_count="$(jobs -rp 2>/dev/null | wc -l | tr -d ' ')"
    [[ "${job_count:-0}" -gt 0 ]] && jobs_str="[$job_count] "

    local symbol_str="$col_ok"
    [[ "$last_exit" -ne 0 ]] && symbol_str="$col_err"
    [[ -n "$theme_symbol_prefix" ]] && symbol_str="$symbol_str$theme_symbol_prefix"

    if [[ "${EUID}" -eq 0 ]]; then symbol_str="$symbol_str# ${c_reset}"; else symbol_str="$symbol_str$ ${c_reset}"; fi

    if [[ "$theme_multiline" -eq 1 ]]; then
        if [[ -n "$host_str" ]]; then
            export PS1="$venv_str$host_str $dir_str$git_str$time_display$jobs_str\n$symbol_str"
        else
            export PS1="$venv_str$dir_str$git_str$time_display$jobs_str\n$symbol_str"
        fi
    else
        if [[ -n "$host_str" ]]; then
            export PS1="$venv_str$host_str$theme_separator$dir_str$git_str$time_display$jobs_str$symbol_str"
        else
            export PS1="$venv_str$dir_str$git_str$time_display$jobs_str$symbol_str"
        fi
    fi
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
    main "$LIMON_THEME_ARG"
}
export -f limon_runner

export LIMON_THEME_ARG="$THEME_NAME"

case "$SUBCOMMAND" in
    on)
        __LIMON_CMD_START=$SECONDS
        PROMPT_COMMAND="limon_runner${DEFAULT_PROMPT_COMMAND:+; $DEFAULT_PROMPT_COMMAND}"
        LAST_EXIT_CODE=${LAST_EXIT_CODE:-0}
        __LIMON_CMD_ELAPSED=0
        limon_runner
        _limon_maybe_autoupdate
        ;;
    upgrade|update)
        _limon_do_upgrade
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
            unset __LIMON_GIT_CACHE_PWD __LIMON_GIT_CACHE_SEC \
                  __LIMON_GIT_CACHE_BRANCH __LIMON_GIT_CACHE_MARKS
            _limon_load_config
            export LIMON_TIMER_THRESHOLD LIMON_GIT_MODE LIMON_SHOW_HOST LIMON_SHOW_SSH
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
        echo "Theme: $saved_theme"
        theme_path="$(_limon_resolve_theme_file "$saved_theme" 2>/dev/null || true)"
        if [[ -n "$theme_path" ]]; then
            echo "Theme file: $theme_path"
        else
            echo "Theme file: (built-in defaults)"
        fi
        echo "Config: $LIMON_CONF"
        echo "Options: timer_threshold=$LIMON_TIMER_THRESHOLD git=$LIMON_GIT_MODE show_host=$LIMON_SHOW_HOST show_ssh=$LIMON_SHOW_SSH autoupdate=$LIMON_AUTOUPDATE"
        if _limon_is_git_install; then
            echo "Install: $SCRIPT_DIR (git — upgradable)"
        else
            echo "Install: $SCRIPT_DIR (not a git install — 'limon upgrade' unavailable)"
        fi
        [[ -f "$LIMON_UPDATE_FLAG" ]] && echo "Update: a new version is available (run 'limon upgrade')"
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
    config)
        CONFIG_ARG="${1:-}"
        if [[ -z "$CONFIG_ARG" ]]; then
            echo "Usage: limon config timer_threshold=N|git=full|lite|off|show_host=0|1|show_ssh=0|1|autoupdate=off|notify|on"
            echo "Current: timer_threshold=$LIMON_TIMER_THRESHOLD git=$LIMON_GIT_MODE show_host=$LIMON_SHOW_HOST show_ssh=$LIMON_SHOW_SSH autoupdate=$LIMON_AUTOUPDATE"
        else
            config_ok=0
            case "$CONFIG_ARG" in
                timer_threshold=*) LIMON_TIMER_THRESHOLD="${CONFIG_ARG#*=}"; config_ok=1 ;;
                git=*) LIMON_GIT_MODE="${CONFIG_ARG#*=}"; config_ok=1 ;;
                show_host=*) LIMON_SHOW_HOST="${CONFIG_ARG#*=}"; config_ok=1 ;;
                show_ssh=*) LIMON_SHOW_SSH="${CONFIG_ARG#*=}"; config_ok=1 ;;
                autoupdate=*)
                    case "${CONFIG_ARG#*=}" in
                        off|notify|on) LIMON_AUTOUPDATE="${CONFIG_ARG#*=}"; config_ok=1 ;;
                        *) echo "limon: autoupdate must be one of: off, notify, on" >&2 ;;
                    esac
                    ;;
                *)
                    echo "limon: unknown config option '$CONFIG_ARG'" >&2
                    echo "Usage: limon config timer_threshold=N|git=full|lite|off|show_host=0|1|show_ssh=0|1|autoupdate=off|notify|on" >&2
                    ;;
            esac
            if [[ "$config_ok" -eq 1 ]]; then
                mapfile -t _limon_flags < <(_limon_conf_flags)
                _limon_write_config "$saved_theme" "${_limon_flags[@]}"
                export LIMON_TIMER_THRESHOLD LIMON_GIT_MODE LIMON_SHOW_HOST LIMON_SHOW_SSH LIMON_AUTOUPDATE
                if _limon_is_active; then
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
    help|"")
        echo "
limon - Optimized Bash Prompt

Usage:
    limon on [theme]     Enable Limon (optionally set theme)
    limon off            Restore default prompt
    limon reload         Reload theme and config
    limon upgrade        Update Limon to the latest version (git pull)
    limon uninstall      Remove Limon (prompts to keep or delete config)
    limon status         Show current state
    limon themes         List available themes
    limon config KEY=VAL Set timer_threshold, git, show_host, show_ssh, or autoupdate
    limon colors         Show ANSI color codes
    limon help           Show this help

Auto-update:
    limon config autoupdate=off     Never check for updates (default)
    limon config autoupdate=notify  Check daily, notify when an update exists
    limon config autoupdate=on       Check daily, auto-install updates if possible

Config file: $LIMON_CONF
  Example: neon -timer_threshold=3 -git=lite -show_host=1 -show_ssh=1 -autoupdate=notify
"
        ;;
esac
