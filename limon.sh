#!/usr/bin/env bash

# get last exit code
exit_code() {
	LAST_EXIT_CODE=$?
}

# get subcommmand and shift 
SUBCOMMAND="$1"
shift

# get/save last configuration from/to conf file
LIMON_CONF="$HOME/.limon_conf"
if [ $# -eq 0 ]; then
    if [ -f "$LIMON_CONF" ]; then
        read -r -a saved_flags < "$LIMON_CONF"
    else
        echo "no config found. creating default config."
        echo "-s default" > "$LIMON_CONF"
        saved_flags=(-s default)
    fi
    set -- "${saved_flags[@]}"
else
    echo "$@" > "$LIMON_CONF"
fi

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

# set default values
S_CASE=0
POSITIONAL_ARG="default"

# getting args and enabling flags
while getopts ":snc" opt; do
	case $opt in
	  c)
	    FLAG_CONTINOUS=1
	    FLAG_NEW_LINE=0
	    ;;
	  n)
	    FLAG_CONTINOUS=0
	    FLAG_NEW_LINE=1
	    ;;
	  s)
	    S_CASE=1
	    FLAG_SILENT=1 
	    ;;
	  \?)
	    echo "Invalid Flag: -$OPTARG" >&2 
	    ;;
	esac
done
shift $((OPTIND - 1))

# getting theme value
POSITIONAL_ARG="$1"

# main func to control limon when it's on
main() {
	structure_GIT=1
	
	# get args
	local silent=$FLAG_SILENT
    	local newline=$FLAG_NEW_LINE
    	local continous=$FLAG_CONTINOUS
	local theme=$POSITIONAL_ARG
	
	# define all colors
	local c_black='\[\033[1;30m\]'
	local c_red='\[\033[1;31m\]'
	local c_green='\[\033[1;32m\]'
	local c_yellow='\[\033[1;33m\]'
	local c_blue='\[\033[1;34m\]'
	local c_purple='\[\033[1;35m\]'
	local c_cyan='\[\033[1;36m\]'
	local c_white='\[\033[1;37m\]'
	local c_gray='\[\033[1;90m\]'

	# define git symbols
	local sym_git_branch=''
    	local sym_git_modified=' (@)'
    	local sym_git_push='↑'
    	local sym_git_pull='↓'
	
	local color_reset='\[\033[m\]'
        
	# selecting color patterns for each thmme
	case "$theme" in
		default)
			lim_color_ok=$c_cyan
                       	lim_color_err=$c_red
                        lim_color_git=$c_yellow
                        lim_color_dir=$c_cyan
                        lim_color_host=$c_green
			;;
                git_bash)
                        lim_color_ok=$c_cyan
                        lim_color_err=$c_red
                        lim_color_git=$c_cyan
                        lim_color_dir=$c_yellow
                        lim_color_host=$c_green
                        ;;
                *)
                        ;;
	esac
	
	# func to get info abou git dir
	git_info() {
		# diabled by you
		[[ $structure_GIT = 0 ]] && return
        	
		# git not installed, if hash will give any error
		hash git 2>/dev/null || return
		
		# forces git to output in eng
        	local git_eng="env LANG=C git"

		# get currwnt branch name 	
        	local br_name=$($git_eng symbolic-ref --short HEAD 2>/dev/null)

        	if [[ -n "$br_name" ]]; then
			# put branch symbol
            		br_name=$br_name
        	else
			# get tag name or short unique hash
            		br_name=$($git_eng describe --tags --always 2>/dev/null)
        	fi

		# not a it repo
        	[[ -n "$br_name" ]] || return

        	local marks

        	# scan first two lines of output from `git status`
        	while IFS= read -r line; do
			# header line
            		if [[ $line =~ ^## ]]; then
                		[[ $line =~ ahead\ ([0-9]+) ]] && marks+=" $sym_git_push${BASH_REMATCH[1]}"
                		[[ $line =~ behind\ ([0-9]+) ]] && marks+=" $sym_git_pull${BASH_REMATCH[1]}"
            		else
                		# branch modified if output's more line after header
                		marks="$sym_git_modified$marks"
                		break
            		fi
        	done < <($git_eng status --porcelain --branch 2>/dev/null)

        	# print the git branch status
		case "$theme" in
                	default)
                        	printf "$marks [$br_name]"
                        	;;
                	git_bash)
                        	printf "$marks ($br_name)"
                        	;;
                	*)
                        	;;
        	esac
	}
	
	#func to color virtual env indicator
	color_venv() {
        	if [[ -z "$VIRTUAL_ENV" ]]; then
            		local the_venv_info=''
        	else
            		local the_venv_info=$color_reset'(venv) '
        	fi
		printf "$the_venv_info"
	}
	
	# func to color host & user section
	color_host() {
            	local the_hostname=$lim_color_host'\u@\h'
		printf "%s" "$the_hostname"
	}
	
	#func to color dir section
	color_dir() {
        	dir_owner_uid=$(stat -c '%u' . 2> /dev/null)

		current_uid=$(id -u 2> /dev/null)

		local dir_flag
		if [ "$dir_owner_uid" -eq "$current_uid" ] 2>/dev/null; then
    			local dir_flag=1		
		else
    			local dir_flag=0
		fi

		if [ "$current_uid" -eq 0 ]; then
			# for root user 
			# if path '/root*' or '/home*', color normal for other '/' subdirs, red
			if [[ "$PWD" != /root* && "$PWD" != /home* && "$PWD" == /* ]]; then
            			local the_dir_info=$lim_color_err'\w'
        		else
            			local the_dir_info=$lim_color_dir'\w'
        		fi

		else
			# for normal user 
			# if user has permission on dir, color normal and if not, gray
			if [ $dir_flag -eq 1 ] 2>/dev/null; then
            			local the_dir_info=$lim_color_dir'\w'
        		else
            			local the_dir_info=$c_gray'\w'
        		fi
		fi
		printf "%s" "$the_dir_info"
	}
	
	#func to color git section
	color_git() {
		if shopt -q promptvars; then
			local info="$1"
            		local the_git=$lim_color_git$info
        	else
            		local the_git=$lim_color_git$info
        	fi

		echo "$the_git"
	}
	
	#func too color prompt ready indicator
	color_symbol() {	
		# check last exit code and color red if err
		local symbol

		if [ $LAST_EXIT_CODE -eq 0 ]; then
            		local symbol=$lim_color_ok
        	else
            		local symbol=$lim_color_err
        	fi
        	
		# check user status if superuser "#" else "$"
        	if [ "$(id -u)" -eq 0 ]; then
			case "$theme" in
                        default)
                        local symbol="$symbol"
                        ;;
                        git_bash)
                        local symbol="$symbol╠═"
                        ;;
                        *)
                        local symbol="$symbol"
                        ;;
                esac

            		local symbol="$symbol# "$color_reset
        	else
            		local symbol="$symbol$ "$color_reset
        	fi
		printf "%s" "$symbol"

	}
	
	local the_git_info=$(git_info)
		
	local the_venv=$(color_venv)
	local the_host=$(color_host)
	local the_dir=$(color_dir)
	local the_git=$(color_git "$the_git_info")
	local the_symbol=$(color_symbol)

	# finally set PS1
	case "$theme" in
                default)
                        export PS1="$the_venv$the_host:$the_dir$the_git$the_symbol"
                        ;;
                git_bash)
                        export PS1="$the_venv$the_host $the_dir$the_git\n$the_symbol"
                        ;;
                *)
                        ;;
        esac

	# return FLAG_SILENT to back state if S_CASE is 0
	if [[ -z "$FLAG_SILENT" || "$FLAG_SILENT" -eq 1 ]] && [[ "$S_CASE" -eq 0 ]]; then
    		FLAG_SILENT=0
	else
    		FLAG_SILENT=1
	fi

}


# func to turn on limon
__structure_on() {
	structure_GIT=1
    	# Update PROMPT_COMMAND
    	PROMPT_COMMAND="exit_code; main${DEFAULT_PROMPT_COMMAND:+; $DEFAULT_PROMPT_COMMAND}"
}



# func to turn off the limon and return PS1 to system default
__structure_off() {
    structure_GIT=0
    export PS1="$DEFAULT_PS1"
    PROMPT_COMMAND="$DEFAULT_PROMPT_COMMAND"
}

# main controller logic of script
case "$SUBCOMMAND" in
    on)
	__structure_on
	if [[ "$FLAG_SILENT" -eq 0 ]]; then
            echo "limon enabled"
        else
            :
        fi
        ;;

    off)
	__structure_off
        if [[ "$FLAG_SILENT" -eq 0 ]]; then
	    echo "limon disabled"
	else
	    :	
	fi
    	;;
    help)
        echo "
limon is the bash color Prompt

Usage:
        on [-s] <theme name>: turn on the limon
        off [-s]: turn off the limon and restore system PS1
        help : help to use command

        adding '-s' option to on/off indicated the silent mode
"
        ;;
esac
