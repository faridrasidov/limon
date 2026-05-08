# bash completion for limon

_limon_autocomplete() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Updated commands list
    local commands="on off colors help"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        # After 'limon' suggest commands
        COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )
        
    elif [[ ${COMP_CWORD} -eq 2 && "${prev}" == "on" ]]; then
        # Dynamically fetch available themes from config directories
        local themes=""
        local theme_dirs=(
            "${XDG_CONFIG_HOME:-$HOME/.config}/limon/themes"
            "/usr/share/limon/themes"
        )
        
        for dir in "${theme_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                # Loop through all .theme files and strip the path/extension
                for file in "$dir"/*.theme; do
                    if [[ -f "$file" ]]; then
                        local name="${file##*/}"
                        name="${name%.theme}"
                        themes="${themes} ${name}"
                    fi
                done
            fi
        done
        
        # Suggest the dynamically found themes
        COMPREPLY=( $(compgen -W "${themes}" -- "${cur}") )
    fi
}

complete -F _limon_autocomplete limon
