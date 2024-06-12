#!/usr/bin/env bash

# Uncomment to disable git info
# structure_GIT=0

__structure() {
    # Colors
    COLOR_RESET='\[\033[m\]'     # No Color
    COLOR_OK='\[\033[1;36m\]'    # Aqua
    COLOR_ERR='\[\033[1;31m\]'   # Red
    COLOR_GIT='\[\033[1;33m\]'   # Yellow
    COLOR_HOST='\[\033[1;32m\]'  # Green

    # Symbols
    SYMBOL_GIT_BRANCH=''
    SYMBOL_GIT_MODIFIED=' (@)'
    SYMBOL_GIT_PUSH='↑'
    SYMBOL_GIT_PULL='↓'

    __git_info() {
        [[ $structure_GIT = 0 ]] && return   # Disabled By You.
        hash git 2>/dev/null || return       # Git Not Installed.
        local git_eng="env LANG=C git"       # Forces Git To Output In English To Make Our Work Easier.
        local ref=$($git_eng symbolic-ref --short HEAD 2>/dev/null)          # Get Current Branch Name.

        if [[ -n "$ref" ]]; then
            ref=$ref       # Put Branch Symbol
        else
            ref=$($git_eng describe --tags --always 2>/dev/null)    # get tag name or short unique hash.
        fi
        [[ -n "$ref" ]] || return            # Not A Git Repo

        local marks

        # Scan First Two Lines Of Output From `git status`
        while IFS= read -r line; do
            if [[ $line =~ ^## ]]; then      # Header Line
                [[ $line =~ ahead\ ([0-9]+) ]] && marks+=" $SYMBOL_GIT_PUSH${BASH_REMATCH[1]}"
                [[ $line =~ behind\ ([0-9]+) ]] && marks+=" $SYMBOL_GIT_PULL${BASH_REMATCH[1]}"
            else
                # Branch Modified if Output Has More Lines After Header Line
                marks="$SYMBOL_GIT_MODIFIED$marks"
                break
            fi
        done < <($git_eng status --porcelain --branch 2>/dev/null)

        # Print The Git Branch Status
        # \'●\' change after last commit
        # \'↑\' Not Committed To Remote
        # \'↓\' Not Synced With Remote
        printf "$marks [$ref]"
    }

    General() {
        # Check Last Exit Code And Display Red if ERR or Aqua OK
        if [ $LAST_EXIT_CODE -eq 0 ]; then
            Zymbol=$COLOR_OK
        else
            Zymbol=$COLOR_ERR
        fi
        # Check User status if superuser "#" else "$"
        if [ "$(id -u)" -eq 0 ]; then
            Zymbol="$Zymbol# $COLOR_RESET"
        else
            Zymbol="$Zymbol$ $COLOR_RESET"
        fi

        # If Path Is In '/root' Or '/home' Color Aqua and When it's in another '/' Folder, Red.
        if [[ "$PWD" != /root* && "$PWD" != /home* && "$PWD" == /* ]]; then
            local HostName=$COLOR_HOST'\u@\h:'$COLOR_ERR'\w'$COLOR_RESET
            #local Zymbol="$COLOR_ERR$userpriv $COLOR_RESET"
        else
            local HostName=$COLOR_HOST'\u@\h:'$COLOR_OK'\w'$COLOR_RESET
        fi

	# Getting venv Info
        if [[ -z "$VIRTUAL_ENV" ]]; then
            local Vena=''
        else
            local Vena=$COLOR_RESET'(venv)'$COLOR_RESET
        fi

        # Getting Git Info
        if shopt -q promptvars; then
            __structure_git_info="$(__git_info)"
            local git="$COLOR_GIT\${__structure_git_info}$COLOR_RESET"
        else
            local git="$COLOR_GIT$(__git_info)$COLOR_RESET"
        fi

        # All In One
        PS1="$Vena$HostName$git$Zymbol"
    }

    CaptureExitCode() {
        LAST_EXIT_CODE=$?
    }

    PROMPT_COMMAND="CaptureExitCode; General${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
}

__structure
#unset __structure

