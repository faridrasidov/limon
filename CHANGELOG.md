# Changelog

All notable changes to Limon should be documented in this file.

The format follows a simple, release-oriented structure:

- `Added` for new features.
- `Changed` for behavior changes.
- `Fixed` for bug fixes.
- `Docs` for documentation-only changes.

## 1.2.0 - 2026-09-20

### Upgrade notes

- Bash 4.4 or newer is now required. Limon's native timer uses Bash 4.4's
  `PS0` support so it no longer needs a global `DEBUG` trap.
- Release archives are about 2.3 MB larger because they bundle the
  architecture-independent ble.sh runtime. No compiler, platform-specific
  binary, or runtime download is required.

### Added

- Fish/Zsh-style inline ghost autosuggestions for command history, commands,
  paths, and programmable completions. Right Arrow or End accepts the full
  suggestion; Ctrl+Right accepts one word; Tab remains normal completion.
- Autosuggestions are enabled by default and can be controlled with
  `autosuggest=0|1`, `autosuggest_delay=0..2000`, and
  `autosuggest_color=auto|0..255`.
- Limon reuses an already-loaded ble.sh session or loads its bundled pinned
  copy. `limon status` and `limon health` report the editor, hook provider, and
  bash-completion state.
- PTY coverage for rendering and accepting a real history suggestion, plus
  lifecycle tests for scalar and array `PROMPT_COMMAND` values.

### Changed

- The command timer and prompt renderer use ble.sh's public `PREEXEC` and
  `PRECMD` hooks when its editor is active. The native fallback uses `PS0` and
  a composable `PROMPT_COMMAND` entry.
- Bash 5.1+ preserves `PROMPT_COMMAND` as an array. Bash 4.4-5.0 uses an exact,
  removable scalar prefix and does not restore a stale startup snapshot.
- The bundled editor enables only ghost suggestions: syntax highlighting,
  completion menus, EOF markers, and other visual ble.sh defaults are disabled.
- `limon off` disables every Limon-owned editor feature and hook. A bundled
  ble.sh runtime already sourced into the current Bash process stays resident
  but inert until that shell exits; ble.sh does not support a silent full
  unload back into Readline.
- The installer no longer forces `TERM=xterm-256color` and now safely quotes
  installed paths written to `.bashrc`.

### Fixed

- Alt+Backspace deletes the previous path component or word again. The bundled
  ble.sh bound it to `copy-backward-sword`, which copied instead of deleting
  and ignored `/`; Limon now binds it to `kill-backward-cword` in its own
  ble.sh instance only (#11).
- `limon off` removes only Limon-owned hooks and restores an existing ble.sh
  configuration without detaching a user-owned editor.
- Existing `DEBUG` traps are no longer replaced by Limon, fixing compatibility
  with debuggers and other shell frameworks.

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
