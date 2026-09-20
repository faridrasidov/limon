# Changelog

All notable changes to Limon should be documented in this file.

The format follows a simple, release-oriented structure:

- `Added` for new features.
- `Changed` for behavior changes.
- `Fixed` for bug fixes.
- `Docs` for documentation-only changes.

## 1.1.0 - 2026-09-20

### Upgrade notes

- **Bash 4.0 or newer is now required**, and Limon checks for it at startup
  instead of failing somewhere deep in the script. macOS ships Bash 3.2 as
  `/bin/bash`; install a current one with `brew install bash` and use that
  shell. Limon never fully worked on 3.2 — it installed the prompt but silently
  failed to persist config options — so this names a broken setup rather than
  dropping a working one.
- `LIMON_*` configuration options are no longer exported into child processes.
  Nothing documented relied on this, but a script reading e.g. `$LIMON_GIT_MODE`
  from a subprocess started by your shell will no longer see it.
- `timer_threshold` now rejects values it used to accept silently. If your
  config has a non-numeric value there, Limon falls back to the 2 second
  default and `limon config timer_threshold=...` will tell you why.

### Added

- A dependency-free test suite (`bash tests/run.sh`) and CI running it on Bash
  4.4, 5.0 and 5.2 alongside ShellCheck and a prompt render-time guard.
- `limon bench --breakdown` reports per-segment render timings, so a slowdown
  can be attributed instead of guessed at.
- Sub-second command timer: durations now render as `1.4s`, `2m 05s` or
  `1h 02m 05s`. Bash 4 has no fork-free high-resolution clock, so those shells
  keep whole-second timing rather than paying a `date` call before every
  command.
- `timer_threshold` accepts fractions, e.g. `limon config timer_threshold=0.5`.
- `LIMON_SOURCE_ONLY=1` loads Limon's functions without parsing a subcommand or
  installing the prompt, for testing and debugging.

### Changed

- Prompt rendering is roughly 70 times faster — about 21 ms per prompt down to
  about 0.3 ms. The theme file was being re-validated and re-sourced on every
  keypress, and every prompt segment was assembled through a subshell. Themes
  are now cached, and the segments no longer fork.
- `limon reload` re-sources Limon, so a shell left open across `limon upgrade`
  picks up the new code instead of silently running the old prompt renderer.
- Default `host_color` is now `off`, so Limon uses the selected theme's host
  color unless you enable automatic hostname coloring with
  `limon config host_color=auto`.
- Default `show_root` is now `0`, so the ROOT warning banner is opt-in with
  `limon config show_root=1`.

### Fixed

- `limon config max_path=N` with a small `N` could hang the shell on every
  prompt. The path-shortening loop could never make progress, so the prompt
  never returned.
- `limon off` left its `DEBUG` trap installed, so Limon's timing hook kept
  running on every command in a shell you had turned Limon off in. The trap is
  now disarmed. Note that Bash does not let a sourced script see the caller's
  `DEBUG` trap, so `limon off` cannot restore a trap you had set before
  `limon on` — it clears Limon's instead of putting yours back.
- Limon failed with "unbound variable" errors in shells using `set -u`.
- Limon exported a shell function named `main` into every child process, where
  a script calling `main` before defining it would run Limon's prompt renderer
  instead of its own entry point.
- Command timing starts only when Bash is about to run a real command, so idle
  time spent sitting at the prompt is no longer counted as command duration.
- On Bash 4, where timing has whole-second resolution, the timer rendered
  `1.0s` — claiming a precision the measurement did not have. It now shows `1s`.

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
