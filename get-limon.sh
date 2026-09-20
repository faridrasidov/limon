#!/usr/bin/env bash
#
# Limon bootstrap installer
# Copyright (C) 2026 Farid Rasidov
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SPDX-License-Identifier: GPL-3.0-or-later
# See the LICENSE file for the full text.
#
# This is the one-line install entry point:
#
#   curl -fsSL https://raw.githubusercontent.com/faridrasidov/limon/master/get-limon.sh | bash
#
# It downloads Limon and hands off to install.sh. install.sh cannot do this
# itself: it only copies from a directory that already exists on disk.
#
# Where possible it clones with git, because install.sh copies the .git
# directory along with the files and that is what makes `limon upgrade` work
# later. Without git it falls back to a release tarball, and that install can
# be updated by re-running this script.

set -euo pipefail

REPO_OWNER="faridrasidov"
REPO_NAME="limon"

# Overridable so the installer can be exercised against a local clone in tests
# without reaching the network. Users never need to set these.
REPO_URL="${LIMON_REPO_URL:-https://github.com/${REPO_OWNER}/${REPO_NAME}}"
API_URL="${LIMON_API_URL:-https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}}"

# --- Bash version gate -------------------------------------------------------
# Matches the check in limon.sh and install.sh. Fail here rather than download
# anything we already know will not run.
if [[ -z "${BASH_VERSINFO[0]:-}" ]] || \
   (( BASH_VERSINFO[0] < 4 || BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4 )); then
    echo "limon: requires bash 4.4 or newer (found ${BASH_VERSION:-unknown})." >&2
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        echo "limon: macOS ships bash 3.2 as /bin/bash. Install a newer one with:" >&2
        echo "limon:   brew install bash" >&2
        echo "limon: then run this installer again using that bash." >&2
    fi
    exit 1
fi

# --- Options -----------------------------------------------------------------
SCOPE_FLAG=""          # passed through to install.sh
ASSUME_YES=""
CHANNEL="stable"
VERSION=""             # empty = latest release
INSTALL_DIR=""

usage() {
    cat <<EOF
Limon installer

Usage:
  curl -fsSL ${REPO_URL}/raw/master/get-limon.sh | bash
  bash get-limon.sh [options]

Options:
  --system            Install for all users (needs sudo)
  --user              Install for the current user (default)
  --channel NAME      stable (default), beta, or dev — only with git
  --version X.Y.Z     Install a specific release instead of the latest
  --dir PATH          Install into PATH/limon instead of the default location
  -y, --yes           Do not ask anything
  -h, --help          Show this help

With no options Limon installs for the current user, and nothing outside
your home directory is touched.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --system)  SCOPE_FLAG="--system" ;;
        --user)    SCOPE_FLAG="--user" ;;
        --channel) CHANNEL="${2:-}"; shift ;;
        --version) VERSION="${2:-}"; shift ;;
        --dir)     INSTALL_DIR="${2:-}"; shift ;;
        -y|--yes)  ASSUME_YES="--yes" ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "limon: unknown option '$1'" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

case "$CHANNEL" in
    stable) BRANCH="master" ;;
    beta)   BRANCH="beta" ;;
    dev)    BRANCH="dev" ;;
    *)
        echo "limon: unknown channel '$CHANNEL' (expected stable, beta, or dev)" >&2
        exit 2
        ;;
esac

# --- Output ------------------------------------------------------------------
say()  { printf '%s\n' "$*"; }
fail() { printf 'limon: %s\n' "$*" >&2; exit 1; }

# --- Temp workspace ----------------------------------------------------------
WORK=""
cleanup() { [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"; }
trap cleanup EXIT

# --- Download helpers --------------------------------------------------------
# fetch_to <url> <dest-file>
fetch_to() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    else
        wget -qO "$dest" "$url"
    fi
}

# fetch_stdout <url>
fetch_stdout() {
    local url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url"
    else
        wget -qO- "$url"
    fi
}

have_downloader() {
    command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1
}

# Resolve the tag of the newest published release, e.g. "v1.2.0".
latest_tag() {
    fetch_stdout "${API_URL}/releases/latest" \
        | grep -m1 '"tag_name"' \
        | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# verify_checksum <file> <name-in-SHA256SUMS> <sums-file>
# Skips with a warning when no checksum tool is available, rather than failing
# an otherwise fine install on a minimal system.
verify_checksum() {
    local file="$1" name="$2" sums="$3" expected actual

    expected="$(grep -E "[[:space:]]\*?${name}\$" "$sums" 2>/dev/null | awk '{print $1}' | head -1)"
    if [[ -z "$expected" ]]; then
        say "limon: no checksum published for ${name}, skipping verification"
        return 0
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        actual="$(sha256sum "$file" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
        actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    else
        say "limon: no sha256 tool found, skipping checksum verification"
        return 0
    fi

    [[ "$actual" == "$expected" ]] || fail "checksum mismatch for ${name} — refusing to install"
    say "limon: checksum verified"
}

# --- Fetch Limon -------------------------------------------------------------
WORK="$(mktemp -d)"
SRC=""

if command -v git >/dev/null 2>&1 && [[ -z "$VERSION" ]]; then
    # Preferred path. install.sh copies the .git directory along with the
    # files, which is what lets `limon upgrade` pull future updates.
    say "limon: downloading Limon (${CHANNEL} channel)..."
    if ! git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORK/limon" 2>/dev/null; then
        fail "could not download Limon from ${REPO_URL} (branch ${BRANCH}). Check your connection and try again."
    fi
    SRC="$WORK/limon"
else
    have_downloader || fail "need either curl or wget to download Limon, and neither is installed."

    local_tag="${VERSION:+v$VERSION}"
    if [[ -z "$local_tag" ]]; then
        say "limon: looking up the latest release..."
        local_tag="$(latest_tag || true)"
        [[ -n "$local_tag" ]] || fail "could not determine the latest release. Try again, or pass --version X.Y.Z."
    fi

    ver="${local_tag#v}"
    tarball="limon-${ver}.tar.gz"
    say "limon: downloading Limon ${ver}..."

    fetch_to "${REPO_URL}/releases/download/${local_tag}/${tarball}" "$WORK/$tarball" \
        || fail "could not download ${tarball}. Check that release ${local_tag} exists."

    if fetch_to "${REPO_URL}/releases/download/${local_tag}/SHA256SUMS" "$WORK/SHA256SUMS" 2>/dev/null; then
        verify_checksum "$WORK/$tarball" "$tarball" "$WORK/SHA256SUMS"
    fi

    command -v tar >/dev/null 2>&1 || fail "need tar to unpack Limon, and it is not installed."
    tar -xzf "$WORK/$tarball" -C "$WORK" || fail "could not unpack ${tarball}."
    SRC="$WORK/limon-${ver}"
    [[ -d "$SRC" ]] || fail "unexpected archive layout in ${tarball}."
fi

[[ -f "$SRC/install.sh" ]] || fail "downloaded copy is missing install.sh — please report this."

# --- Hand off to the real installer -----------------------------------------
INSTALL_ARGS=()
[[ -n "$SCOPE_FLAG" ]] && INSTALL_ARGS+=("$SCOPE_FLAG")
[[ -n "$ASSUME_YES" ]] && INSTALL_ARGS+=("$ASSUME_YES")

if [[ -n "$INSTALL_DIR" ]]; then
    # install.sh derives its user target as "$XDG_DATA_HOME/limon", so point
    # that at the requested parent and Limon lands in "$INSTALL_DIR/limon".
    XDG_DATA_HOME="$INSTALL_DIR"
    export XDG_DATA_HOME
    say "limon: installing into ${INSTALL_DIR}/limon"
fi

bash "$SRC/install.sh" ${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"}
