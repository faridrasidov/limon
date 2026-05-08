#!/usr/bin/env bash

# limon - Optimized Bash Prompt
# Features: 256-Color ANSI Support, Color Picker, Silent Default, Modular Themes

# --- 1. Self-Healing & Safety ---
if [[ "$DEFAULT_PROMPT_COMMAND" == *"not found"* ]] || \
   [[ "$DEFAULT_PROMPT_COMMAND" == *"limon_runner"* ]] || \
   [[ "$DEFAULT_PROMPT_COMMAND" == *"PROMPT_COMMAND"* ]]; then
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

# --- 3. Subcommand & Config Loading ---
SUBCOMMAND="$1"
shift

# A. Extract "Saved Theme"
saved_theme="default"
if [ -f "$LIMON_CONF" ]; then
    read -r -a conf_parts < "$LIMON_CONF"
    for part in "${conf_parts[@]}"; do
        if [[ "$part" != -* ]]; then
            saved_theme="$part"
        fi
    done
fi

# B. Handle Arguments
THEME_NAME="$1"
if [[ -z "$THEME_NAME" ]]; then
    THEME_NAME="$saved_theme"
fi

# --- 4. Save State ---
if [[ "$SUBCOMMAND" == "on" ]]; then
    echo "$THEME_NAME" > "$LIMON_CONF"
fi

# --- 5. Timer Logic ---
timer_start() {
    timer=${timer:-$SECONDS}
}

# --- 6. Main Prompt Function ---
main() {
    local last_exit=$LAST_EXIT_CODE
    local theme_name="${1:-default}"
    
    # --- DEFAULT COLORS (256 ANSI) ---
    # These act as fallbacks if the theme file doesn't define them
    local col_ok='\[\e[38;5;44m\]'      # Teal (44)
    local col_err='\[\e[38;5;160m\]'    # Red (160)
    local col_git='\[\e[38;5;214m\]'    # Orange (214)
    local col_dir='\[\e[38;5;39m\]'     # Blue (39)
    local col_host='\[\e[38;5;118m\]'   # Bright Green (118)
    local col_time='\[\e[38;5;242m\]'   # Grey (242)
    local theme_multiline=0
    local theme_separator=":"
    local theme_symbol_prefix=""

    # Theme Loading
    local theme_file=""
    local search_paths=(
        "$LIMON_CONF_DIR/themes/${theme_name}.theme"
        "/usr/share/limon/themes/${theme_name}.theme"
        "$SCRIPT_DIR/themes/${theme_name}.theme"
    )

    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            theme_file="$path"
            break
        fi
    done
    [[ -n "$theme_file" ]] && source "$theme_file"

    # Timer
    local elapsed_str=""
    if [[ -n "$timer" ]]; then
        local elapsed=$((SECONDS - timer))
        if [[ $elapsed -ge 2 ]]; then
             local min=$((elapsed / 60))
             local sec=$((elapsed % 60))
             [[ $min -gt 0 ]] && elapsed_str=" ${min}m ${sec}s" || elapsed_str=" ${sec}s"
        fi
        unset timer
    fi

    local c_reset='\[\e[m\]'
    local c_gray='\[\e[38;5;240m\]'

    # Git
    local git_str=""
    if command -v git >/dev/null 2>&1; then
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local branch="" marks="" push_count=0 pull_count=0
            while IFS= read -r line; do
                if [[ "$line" =~ ^## ]]; then
                    if [[ "$line" =~ "Initial commit on" ]]; then branch="master"
                    elif [[ "$line" =~ ^##\ (HEAD\ \(no\ branch\)) ]]; then branch="${BASH_REMATCH[1]}"
                    elif [[ "$line" =~ ^##\ ([^.[:space:]]+) ]]; then branch="${BASH_REMATCH[1]}"
                    fi
                    [[ "$line" =~ ahead\ ([0-9]+) ]] && push_count=${BASH_REMATCH[1]}
                    [[ "$line" =~ behind\ ([0-9]+) ]] && pull_count=${BASH_REMATCH[1]}
                else
                    if [[ "$line" == \?\?* ]]; then marks+=" ?"; else marks+=" (@)"; fi
                fi
            done < <(git status --porcelain --branch 2>/dev/null)

            local final_marks=""
            [[ "$marks" == *"(@)"* ]] && final_marks+=" (@)"
            [[ "$marks" == *"?"* ]] && final_marks+=" ?"
            [[ $push_count -gt 0 ]] && final_marks+=" ↑$push_count"
            [[ $pull_count -gt 0 ]] && final_marks+=" ↓$pull_count"
            
            if [[ "$theme_multiline" -eq 1 ]]; then
                 git_str="$col_git$final_marks ($branch)"
            else
                 git_str="$col_git$final_marks [$branch]"
            fi
        fi
    fi

    # Envs
    local venv_str=""
    [[ -n "$VIRTUAL_ENV" ]] && venv_str="(venv) "
    [[ -n "$CONDA_DEFAULT_ENV" ]] && venv_str="(conda:$CONDA_DEFAULT_ENV) "
    [[ -n "$DOCKER_MACHINE_NAME" ]] && venv_str+="(dkr:$DOCKER_MACHINE_NAME) "
    [[ -n "$venv_str" ]] && venv_str="$c_reset$venv_str"

    # Host & Dir
    local host_str="$col_host\u@\h"
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

    # PS1 Construction
    local time_display=""
    [[ -n "$elapsed_str" ]] && time_display="$col_time$elapsed_str "
    
    local symbol_str="$col_ok"
    [[ "$last_exit" -ne 0 ]] && symbol_str="$col_err"
    [[ -n "$theme_symbol_prefix" ]] && symbol_str="$symbol_str$theme_symbol_prefix"
    
    if [[ "${EUID}" -eq 0 ]]; then symbol_str="$symbol_str# ${c_reset}"; else symbol_str="$symbol_str$ ${c_reset}"; fi

    if [[ "$theme_multiline" -eq 1 ]]; then
        export PS1="$venv_str$host_str $dir_str$git_str$time_display\n$symbol_str"
    else
        export PS1="$venv_str$host_str$theme_separator$dir_str$git_str$time_display$symbol_str"
    fi
}
export -f main

# --- 7. Runner ---
limon_runner() {
    LAST_EXIT_CODE=$?
    main "$LIMON_THEME_ARG"
}
export -f limon_runner

export LIMON_THEME_ARG="$THEME_NAME"

case "$SUBCOMMAND" in
    on)
        trap 'timer_start' DEBUG
        PROMPT_COMMAND="limon_runner${DEFAULT_PROMPT_COMMAND:+; $DEFAULT_PROMPT_COMMAND}"
        ;;
    off)
        trap - DEBUG
        export PS1="$DEFAULT_PS1"
        PROMPT_COMMAND="$DEFAULT_PROMPT_COMMAND"
        unset timer
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
    help)
        echo "
limon - Optimized Bash Prompt

Usage:
    limon on [theme]
    limon off
    limon colors    (Show ANSI color codes)
"
        ;;
esac
