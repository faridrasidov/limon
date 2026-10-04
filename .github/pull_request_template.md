## Summary

<!-- What does this change, and why? Link the issue it fixes, e.g. "Fixes #12". -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Performance
- [ ] Theme
- [ ] Docs / tests / CI only

## How was it tested?

<!-- Commands you ran, shells/OSes you tried, before/after output. -->

## Checklist

- [ ] The pull request targets the `dev` branch
- [ ] `bash tests/run.sh` passes
- [ ] `shellcheck -S warning limon.sh install.sh hint-limon.sh get-limon.sh tests/*.sh` is clean
- [ ] New behavior or the bug fix is covered by a test
- [ ] Works on Bash 4.4 (no newer-only features)
- [ ] No new forks in the prompt render path (`limon bench --breakdown` if unsure)
- [ ] `CHANGELOG.md` updated under the newest version section (no `## Unreleased`)
- [ ] `README.md` / `limon help` updated if users can see the change
