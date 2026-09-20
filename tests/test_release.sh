#!/usr/bin/env bash
# Release consistency: the checks that only bite at tag time.
#
# Tagging a release with a stale LIMON_VERSION, or shipping a changelog that
# does not mention the version being released, is invisible until a user
# reports it. These are cheap and catch it in CI instead.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034,SC2088,SC2154
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"

LIMON_SH="$LIMON_REPO_ROOT/limon.sh"
CHANGELOG="$LIMON_REPO_ROOT/CHANGELOG.md"
GET="$LIMON_REPO_ROOT/get-limon.sh"
INSTALL="$LIMON_REPO_ROOT/install.sh"

VERSION="$(grep -m1 '^LIMON_VERSION=' "$LIMON_SH" | cut -d'"' -f2)"
# Newest "## X.Y.Z - date" heading in the changelog.
TOP_CHANGELOG_VERSION="$(grep -m1 -E '^## [0-9]+\.[0-9]+\.[0-9]+' "$CHANGELOG" | sed -E 's/^## ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"

# --- version consistency -----------------------------------------------------

it "limon.sh declares a semantic version"
if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    _limon_t_ok
else
    _limon_t_not_ok "LIMON_VERSION is not X.Y.Z: [$VERSION]"
fi

it "the changelog's newest entry matches LIMON_VERSION"
assert_eq "$VERSION" "$TOP_CHANGELOG_VERSION"

it "the changelog has no leftover Unreleased section"
# Content parked under "Unreleased" at tag time means the release notes will be
# missing it.
unreleased="$(sed -n '/^## Unreleased/,/^## [0-9]/p' "$CHANGELOG" | grep -vE '^## ' | grep -c '[^[:space:]]' || true)"
assert_eq "0" "${unreleased:-0}"

it "limon version reports the declared version"
assert_contains "$(bash "$LIMON_SH" version 2>&1)" "$VERSION"

# --- the files a release ships -----------------------------------------------

for f in limon.sh hint-limon.sh install.sh get-limon.sh README.md CHANGELOG.md LICENSE; do
    it "release payload includes $f"
    assert_ok test -f "$LIMON_REPO_ROOT/$f"
done

it "release payload includes the themes"
assert_ok test -d "$LIMON_REPO_ROOT/themes"

it "every theme file is non-empty"
empty=""
for t in "$LIMON_REPO_ROOT"/themes/*.theme; do
    [[ -s "$t" ]] || empty+=" $(basename "$t")"
done
assert_eq "" "$empty"

# --- bootstrap installer -----------------------------------------------------

it "get-limon.sh is syntactically valid"
assert_ok bash -n "$GET"

it "get-limon.sh --help exits 0"
assert_ok bash "$GET" --help

it "get-limon.sh --help explains the one-line install"
assert_contains "$(bash "$GET" --help)" "get-limon.sh"

it "get-limon.sh rejects an unknown flag"
assert_fail bash "$GET" --definitely-not-a-flag

it "get-limon.sh rejects an unknown channel"
assert_fail bash "$GET" --channel nonsense

it "get-limon.sh accepts each documented channel"
bad=""
for ch in stable beta dev; do
    # --help short-circuits before any network access, so this only exercises
    # argument parsing.
    bash "$GET" --channel "$ch" --help >/dev/null 2>&1 || bad+=" $ch"
done
assert_eq "" "$bad"

it "install.sh is syntactically valid"
assert_ok bash -n "$INSTALL"

it "install.sh --help exits 0"
assert_ok bash "$INSTALL" --help

it "install.sh rejects an unknown flag"
assert_fail bash "$INSTALL" --definitely-not-a-flag

# --- the documented install command matches reality --------------------------

it "the README documents the one-line installer"
assert_contains "$(cat "$LIMON_REPO_ROOT/README.md")" "get-limon.sh"

it "get-limon.sh and install.sh agree on the bash floor"
assert_contains "$(head -50 "$GET")" "BASH_VERSINFO"

finish
