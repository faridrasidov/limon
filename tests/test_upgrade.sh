#!/usr/bin/env bash
# `limon upgrade <channel>` against a real git remote.
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034,SC2154
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/helpers.sh"
use_temp_home

# A fake upstream with master and dev, both carrying the current limon.sh.
UPSTREAM="$HOME/upstream"
make_repo "$UPSTREAM"
cp "$LIMON_REPO_ROOT/limon.sh" "$UPSTREAM/limon.sh"
git -C "$UPSTREAM" add limon.sh
git -C "$UPSTREAM" commit -qm "add limon"
git -C "$UPSTREAM" checkout -q -b dev
echo "dev change" > "$UPSTREAM/DEV"
git -C "$UPSTREAM" add DEV
git -C "$UPSTREAM" commit -qm "dev change"
git -C "$UPSTREAM" checkout -q master

run_upgrade() {
    env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" TERM=xterm-256color \
        bash "$1/limon.sh" upgrade "$2" 2>&1
}

# get-limon.sh clones exactly like this. --depth implies --single-branch, so
# the clone's refspec only covers master.
INSTALL="$HOME/install-shallow"
git clone -q --depth 1 --branch master "file://$UPSTREAM" "$INSTALL" 2>/dev/null

it "a shallow single-branch install only tracks master"
assert_eq "+refs/heads/master:refs/remotes/origin/master" \
    "$(git -C "$INSTALL" config --get-all remote.origin.fetch)"

it "switches a shallow single-branch install to the dev channel"
out="$(run_upgrade "$INSTALL" dev)"
assert_not_contains "$out" "not found"
assert_eq "dev" "$(git -C "$INSTALL" rev-parse --abbrev-ref HEAD)"

it "lands on the dev branch's tip"
assert_eq "$(git -C "$UPSTREAM" rev-parse dev)" "$(git -C "$INSTALL" rev-parse HEAD)"

it "keeps tracking the new branch for later fetches"
assert_contains "$(git -C "$INSTALL" config --get-all remote.origin.fetch)" \
    "+refs/heads/dev:refs/remotes/origin/dev"

it "switches back to stable"
run_upgrade "$INSTALL" stable >/dev/null
assert_eq "master" "$(git -C "$INSTALL" rev-parse --abbrev-ref HEAD)"

it "reports a branch that really does not exist on the remote"
git -C "$UPSTREAM" branch -q -D dev
INSTALL2="$HOME/install-nodev"
git clone -q --depth 1 --branch master "file://$UPSTREAM" "$INSTALL2" 2>/dev/null
out="$(run_upgrade "$INSTALL2" dev)"
assert_contains "$out" "does not exist on 'origin'"
assert_eq "master" "$(git -C "$INSTALL2" rev-parse --abbrev-ref HEAD)"

finish
