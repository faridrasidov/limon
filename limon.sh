#!/usr/bin/env bash

# Save the original PS1 and PROMPT_COMMAND
if [ -z "${DEFAULT_PS1}" ]; then
    DEFAULT_PS1="${PS1}"
    export DEFAULT_PS1
fi

# Set DEFAULT_PROMPT_COMMAND to empty string if PROMPT_COMMAND is not set
if [ -z "${PROMPT_COMMAND}" ]; then
    DEFAULT_PROMPT_COMMAND="${PROMPT_COMMAND}"
else
    DEFAULT_PROMPT_COMMAND=""
fi
export DEFAULT_PROMPT_COMMAND

# Function to define the prompt structure
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
        export PS1="$Vena$HostName$git$Zymbol"
    }

    CaptureExitCode() {
        LAST_EXIT_CODE=$?
    }

    # Update PROMPT_COMMAND
    PROMPT_COMMAND="CaptureExitCode; General${DEFAULT_PROMPT_COMMAND:+; $DEFAULT_PROMPT_COMMAND}"
}

# Function to enable the structure
structure_on() {
    structure_GIT=1
    __structure
    echo "Structure enabled"
}

structure_on_silent() {
    structure_GIT=1
    __structure
}

# Function to disable the structure
structure_off() {
    structure_GIT=0
    export PS1="$DEFAULT_PS1"
    PROMPT_COMMAND="$DEFAULT_PROMPT_COMMAND"
    echo "Structure disabled"
}

structure_off_silent() {
    structure_GIT=0
    export PS1="$DEFAULT_PS1"
    PROMPT_COMMAND="$DEFAULT_PROMPT_COMMAND"
}

# Function to set the structure to default
structure_set_default() {
    structure_GIT=1
    echo "Structure set to default"
}

# Main logic to handle input arguments
case "$1" in
    on) 
	if [[ "$2" == "s" ]]; then
	    structure_on_silent
	else
	    structure_on
	fi
        ;;
    off)
        if [[ "$2" == "s" ]]; then
            structure_off_silent
        else
            structure_off
        fi
        ;;
    set)
        if [[ "$2" == "default" ]]; then
            structure_set_default
        else
            echo "Unknown option: $2"
        fi
        ;;
    help)
        echo "
limon is the bash color Prompt

Usage:
	on [s]: turn on the limon
	off [s]: turn off them limon and restore system PS1
	help : help to use command

	adding [s] option to on/off indicated the silent mode
"
        ;;
esac
