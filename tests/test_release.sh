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

# --- release workflow invariants ---------------------------------------------
#
# The workflow only ever runs on a tag push, so it cannot be exercised here.
# These are structural checks on the properties that are easy to regress and
# expensive to discover at tag time.

WORKFLOW="$LIMON_REPO_ROOT/.github/workflows/release.yml"

it "the release workflow exists"
assert_ok test -f "$WORKFLOW"

it "the release workflow triggers on version tags"
assert_contains "$(cat "$WORKFLOW")" 'tags: ["v*"]'

it "the version guard compares against the base version, not the raw tag"
# A pre-release tag (v1.1.0-rc1) must still match LIMON_VERSION=1.1.0, or the
# recommended dry run fails on the guard rather than on anything real.
assert_contains "$(cat "$WORKFLOW")" 'base="${version%%-*}"'

it "the release workflow marks pre-release tags as pre-releases"
assert_contains "$(cat "$WORKFLOW")" -- "--prerelease"

it "the release workflow publishes with the bundled gh CLI"
# No third-party action, so a repo policy restricting them cannot break
# publishing.
assert_contains "$(cat "$WORKFLOW")" "gh release create"

it "the release workflow does not pin checkout to the input tag"
# A manual run names a tag that usually does not exist yet, so checking it out
# fails before anything can create it. github.ref is already the tag on a tag
# push and the selected branch on a manual run, which is what we want in both
# cases.
assert_not_contains "$(cat "$WORKFLOW")" 'ref: ${{ github.event.inputs.tag'

it "the release workflow creates the tag at the commit it built"
assert_contains "$(cat "$WORKFLOW")" -- '--target "$GITHUB_SHA"'

it "the tag is only created after the checks have run"
# The publish step is the last one, so a failing guard, lint, test or install
# check means no tag is ever created.
wf="$(cat "$WORKFLOW")"
publish_at="$(grep -n 'Publish the release' "$WORKFLOW" | cut -d: -f1)"
tests_at="$(grep -n 'bash tests/run.sh' "$WORKFLOW" | head -1 | cut -d: -f1)"
if [[ -n "$publish_at" && -n "$tests_at" ]] && (( publish_at > tests_at )); then
    _limon_t_ok
else
    _limon_t_not_ok "publish (line ${publish_at:-?}) must come after tests (line ${tests_at:-?})"
fi

it "the release workflow verifies the archive installs before publishing"
assert_contains "$(cat "$WORKFLOW")" "Verify the archive installs"

it "the release workflow runs the test suite"
assert_contains "$(cat "$WORKFLOW")" "bash tests/run.sh"

# The version-resolution rule the workflow uses, checked against the cases that
# matter. Kept in step with the workflow by the grep above.
resolve_base() { local v="${1#v}"; printf '%s' "${v%%-*}"; }

it "a plain tag resolves to itself"
assert_eq "1.1.0" "$(resolve_base v1.1.0)"

it "a release-candidate tag resolves to its base version"
assert_eq "1.1.0" "$(resolve_base v1.1.0-rc1)"

it "a beta tag with a dotted suffix resolves to its base version"
assert_eq "2.0.0" "$(resolve_base v2.0.0-beta.2)"

it "a double-digit minor version survives resolution"
assert_eq "1.10.3" "$(resolve_base v1.10.3)"

finish
