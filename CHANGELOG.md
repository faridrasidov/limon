# Changelog

All notable changes to Limon should be documented in this file.

The format follows a simple, release-oriented structure:

- `Added` for new features.
- `Changed` for behavior changes.
- `Fixed` for bug fixes.
- `Docs` for documentation-only changes.

## Unreleased

### Changed

- Default `host_color` is now `off`, so Limon uses the selected theme's host color unless the user enables automatic hostname coloring with `limon config host_color=auto`.
- Default `show_root` is now `0`, so the ROOT warning banner is opt-in with `limon config show_root=1`.

### Fixed

- Command timing now starts only when Bash is about to execute a real command, so idle time at the prompt is not counted as command duration.
- `limon off` restores a pre-existing DEBUG trap instead of always clearing it.

## 1.0.0 - 2026-07-29

### Added

- Performance metrics with `limon bench`, live render timing via `limon config metrics=1`, and memory reporting.
- Update channels for `stable`, `beta`, and `dev`.
- Theme editing with `limon edit` and theme preview with `limon preview`.
- Health diagnostics with `limon health`.
- Exit-code display and optional exit hints.
- Verbose Git status with staged, modified, untracked, stash, detached HEAD, merge/rebase, and ahead/behind indicators.
- Identity and environment options including host coloring, environment banners, sudo notices, Kubernetes context, and AWS profile display.
- ASCII symbol mode and path truncation.
- Built-in installer and uninstaller.
- Bash completion for `limon` commands, config keys, update channels, and themes.
- Built-in themes including default, limon, neon, sunset, ocean, forest, dracula, nord, mono, high-contrast, and git_bash.

### Changed

- Installer copies Git metadata when installing from a Git checkout so `limon upgrade` can work.
- Git installs set `core.fileMode=false` to avoid executable-bit churn during upgrades.
- README expanded with install, uninstall, update, customization, performance, and FAQ documentation.

### Fixed

- Safer `PROMPT_COMMAND` handling.
- Improved uninstall behavior so the correct installed directory is removed.
- Theme and Git handling were refined across earlier iterations.

### Docs

- Added GPL-3.0-or-later licensing information.
