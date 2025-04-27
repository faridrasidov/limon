# bash completion for limon

_limon_autocomplete() {
    local cur prev prev2 opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    prev2="${COMP_WORDS[COMP_CWORD-2]}"

    local commands="on off set help"
    local flags="-s -n -c"
    local themes="default git_bash"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        # after 'limon' suggest commands
        COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )
    elif [[ " ${commands} " =~ " ${COMP_WORDS[1]} " ]]; then
        if [[ "${cur}" == -* ]]; then
            # if user types '-', suggest flags
            COMPREPLY=( $(compgen -W "${flags}" -- "${cur}") )
        else
            # after flags, suggest themes
            COMPREPLY=( $(compgen -W "${themes}" -- "${cur}") )
        fi
    fi
}

complete -F _limon_autocomplete limon
