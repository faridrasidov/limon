# bash completion for limon

_LIMON_HINT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

_limon_autocomplete() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="on off reload upgrade uninstall status themes config colors version help"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )

    elif [[ ${COMP_CWORD} -eq 2 && "${prev}" == "config" ]]; then
        COMPREPLY=( $(compgen -W "timer_threshold= git= show_host= show_ssh= autoupdate=" -- "${cur}") )

    elif [[ ${COMP_CWORD} -eq 2 && "${prev}" == "on" ]]; then
        local themes=""
        local theme_dirs=(
            "${XDG_CONFIG_HOME:-$HOME/.config}/limon/themes"
            "/usr/share/limon/themes"
            "$_LIMON_HINT_DIR/themes"
        )

        for dir in "${theme_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                for file in "$dir"/*.theme; do
                    if [[ -f "$file" ]]; then
                        local name="${file##*/}"
                        name="${name%.theme}"
                        themes="${themes} ${name}"
                    fi
                done
            fi
        done

        COMPREPLY=( $(compgen -W "${themes}" -- "${cur}") )
    fi
}

complete -F _limon_autocomplete limon
