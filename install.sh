#!/usr/bin/env bash
#
# Limon installer / uninstaller
#
# Usage:
#   ./install.sh                 Install for the current user (no sudo needed)
#   sudo ./install.sh --system   Install system-wide for all users
#   ./install.sh --uninstall     Remove Limon (prompts about the config file)
#   ./install.sh --help          Show this help
#
set -euo pipefail

# --- Constants ---
LIMON_BEGIN="# >>> limon >>>"
LIMON_END="# <<< limon <<<"
FILES=(limon.sh hint-limon.sh)

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/limon"
USER_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/limon"
SYSTEM_DIR="/usr/share/limon"
USER_RC="$HOME/.bashrc"
SYSTEM_RC="/etc/bash.bashrc"

# --- Defaults / argument parsing ---
ACTION="install"
SCOPE=""              # auto-detected if empty
ASSUME_YES=0
PURGE_CONFIG=-1       # -1 = ask, 0 = keep, 1 = remove

usage() {
    cat <<EOF
Limon installer / uninstaller

Usage:
  ./install.sh [options]

Options:
  --system        Install (or uninstall) system-wide in $SYSTEM_DIR (needs root)
  --user          Install (or uninstall) for the current user in $USER_DIR
  --uninstall     Remove Limon instead of installing it
  --purge         When uninstalling, also remove the config dir without asking
  --keep-config   When uninstalling, keep the config dir without asking
  -y, --yes       Assume "yes" to prompts (keeps config unless --purge)
  -h, --help      Show this help

With no options, Limon installs for the current user (root installs system-wide).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --system)    SCOPE="system" ;;
        --user)      SCOPE="user" ;;
        --uninstall|--remove) ACTION="uninstall" ;;
        --purge)     PURGE_CONFIG=1 ;;
        --keep-config) PURGE_CONFIG=0 ;;
        -y|--yes)    ASSUME_YES=1 ;;
        -h|--help)   usage; exit 0 ;;
        *) echo "limon-install: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# Default scope: root -> system, otherwise -> user.
if [[ -z "$SCOPE" ]]; then
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then SCOPE="system"; else SCOPE="user"; fi
fi

if [[ "$SCOPE" == "system" ]]; then
    TARGET_DIR="$SYSTEM_DIR"
    RC_FILE="$SYSTEM_RC"
else
    TARGET_DIR="$USER_DIR"
    RC_FILE="$USER_RC"
fi

# --- Helpers ---
_need_root_for() {
    # Returns 0 if we can write to the given path (creating it if needed).
    # Walks up to the nearest existing ancestor to test writability.
    local dir="$1" parent
    while [[ -n "$dir" && ! -e "$dir" ]]; do
        parent="$(dirname "$dir")"
        if [[ "$parent" == "$dir" ]]; then break; fi
        dir="$parent"
    done
    [[ -w "$dir" ]]
}

_ask_yes_no() {
    # _ask_yes_no "Question?" default(Y/N) -> returns 0 for yes, 1 for no
    local prompt="$1" default="${2:-N}" reply hint="[y/N]"
    if [[ "$ASSUME_YES" -eq 1 || ( ! -t 0 && ! -e /dev/tty ) ]]; then
        if [[ "$default" == "Y" ]]; then return 0; else return 1; fi
    fi
    if [[ "$default" == "Y" ]]; then hint="[Y/n]"; fi
    read -r -p "$prompt $hint " reply </dev/tty || reply=""
    reply="${reply:-$default}"
    case "$reply" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

# Remove the managed Limon block (and legacy manual-install lines) from an rc file.
_strip_rc() {
    local rc="$1"
    [[ -f "$rc" ]] || return 0
    grep -q "$LIMON_BEGIN" "$rc" 2>/dev/null || \
        grep -qE '^alias limon=|hint-limon\.sh|^limon on$' "$rc" 2>/dev/null || return 0

    if [[ ! -w "$rc" ]]; then
        echo "limon-install: cannot edit $rc (no permission) — skipping. Try with sudo." >&2
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    # 1) Drop the marker block. 2) Drop legacy limon-specific lines.
    sed "/$LIMON_BEGIN/,/$LIMON_END/d" "$rc" \
        | grep -vE '^alias limon=|hint-limon\.sh|^limon on$' > "$tmp"
    cat "$tmp" > "$rc"
    rm -f "$tmp"
    echo "limon-install: cleaned Limon entries from $rc"
}

# --- Install ---
do_install() {
    echo "limon-install: installing ($SCOPE) into $TARGET_DIR"

    if ! _need_root_for "$TARGET_DIR"; then
        echo "limon-install: no permission to write $TARGET_DIR." >&2
        echo "limon-install: re-run with sudo, e.g.: sudo ./install.sh --system" >&2
        exit 1
    fi
    if [[ -e "$RC_FILE" && ! -w "$RC_FILE" ]] || { [[ ! -e "$RC_FILE" ]] && ! _need_root_for "$RC_FILE"; }; then
        echo "limon-install: no permission to write $RC_FILE." >&2
        echo "limon-install: re-run with sudo for a system install." >&2
        exit 1
    fi

    mkdir -p "$TARGET_DIR/themes"
    local f
    for f in "${FILES[@]}"; do
        cp -f "$SOURCE_DIR/$f" "$TARGET_DIR/$f"
    done
    cp -f "$SOURCE_DIR/install.sh" "$TARGET_DIR/install.sh" 2>/dev/null || true
    if [[ -d "$SOURCE_DIR/themes" ]]; then
        cp -f "$SOURCE_DIR/themes/"*.theme "$TARGET_DIR/themes/" 2>/dev/null || true
    fi

    # Refresh rc entries idempotently: strip any old block, then append a new one.
    _strip_rc "$RC_FILE"
    {
        printf '%s\n' "$LIMON_BEGIN"
        printf '%s\n' "# Added by the Limon installer. Remove with: $TARGET_DIR/install.sh --uninstall"
        printf '%s\n' "export TERM=xterm-256color"
        printf 'alias limon="source %s/limon.sh"\n' "$TARGET_DIR"
        printf 'source %s/hint-limon.sh\n' "$TARGET_DIR"
        printf '%s\n' "limon on"
        printf '%s\n' "$LIMON_END"
    } >> "$RC_FILE"

    echo "limon-install: done."
    echo "limon-install: installed to $TARGET_DIR"
    echo "limon-install: added startup entries to $RC_FILE"
    echo "limon-install: open a new terminal, or run the line below to enable Limon"
    echo "limon-install: (prompt + tab-completion) in this shell right now:"
    echo "limon-install:     source \"$RC_FILE\""
}

# --- Uninstall ---
do_uninstall() {
    echo "limon-install: uninstalling Limon"

    # Clean startup entries from every rc file we might have touched.
    local rc
    for rc in "$USER_RC" "$SYSTEM_RC"; do
        _strip_rc "$rc"
    done

    # Remove installed files from every known location we can write to.
    local dir removed=0
    for dir in "$SYSTEM_DIR" "$USER_DIR" "$SOURCE_DIR"; do
        [[ -e "$dir/limon.sh" ]] || continue
        # Never delete the repo you're running from if it isn't an install dir.
        if [[ "$dir" == "$SOURCE_DIR" && "$dir" != "$SYSTEM_DIR" && "$dir" != "$USER_DIR" ]]; then
            continue
        fi
        if _need_root_for "$dir"; then
            rm -rf "$dir"
            echo "limon-install: removed $dir"
            removed=1
        else
            echo "limon-install: cannot remove $dir (no permission). Try: sudo $dir/install.sh --uninstall" >&2
        fi
    done
    if [[ "$removed" -eq 0 ]]; then
        echo "limon-install: no installed files removed (already gone or no permission)."
    fi

    # Config directory: prompt unless told otherwise.
    if [[ -d "$CONFIG_DIR" ]]; then
        local do_purge="$PURGE_CONFIG"
        if [[ "$do_purge" -eq -1 ]]; then
            if _ask_yes_no "Remove Limon configuration directory ($CONFIG_DIR)?" "N"; then
                do_purge=1
            else
                do_purge=0
            fi
        fi
        if [[ "$do_purge" -eq 1 ]]; then
            rm -rf "$CONFIG_DIR"
            echo "limon-install: removed config directory $CONFIG_DIR"
        else
            echo "limon-install: kept config directory $CONFIG_DIR"
        fi
    fi

    echo "limon-install: uninstall complete."
    echo "limon-install: open a new terminal to fully restore your default prompt."
}

case "$ACTION" in
    install)   do_install ;;
    uninstall) do_uninstall ;;
esac
