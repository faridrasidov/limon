# Contributing to Limon

Thanks for helping make Limon better! Bug reports, fixes, new themes and ideas
are all welcome. This guide covers how the project is organized and what a
pull request needs in order to be merged.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
Security problems go through the [security policy](SECURITY.md), not public
issues.

## Branches and channels

Limon ships three update channels, and each one is a branch:

| Branch   | Channel  | What lands there                                   |
|----------|----------|----------------------------------------------------|
| `dev`    | `dev`    | Active development. **Open pull requests here.**   |
| `beta`   | `beta`   | Promoted from `dev` for wider testing.             |
| `master` | `stable` | Promoted from `beta`; releases are tagged here.    |

Please base your work on `dev` and target `dev` with your pull request. The
maintainer promotes `dev` → `beta` → `master`.

## Getting set up

You only need Bash 4.4 or newer and git. There is nothing to install.

```shell
git clone https://github.com/faridrasidov/limon.git
cd limon
git checkout dev
source ./limon.sh on    # try your changes in the current shell
```

## Before you open a pull request

Run the same checks CI runs:

```shell
bash tests/run.sh                 # full test suite
bash tests/run.sh git             # only files whose name matches "git"
bash tests/bench_guard.sh         # prompt render-time ceiling
shellcheck -S warning limon.sh install.sh hint-limon.sh get-limon.sh tests/*.sh
```

CI runs the suite on Bash 4.4, 5.0, 5.2 and 5.3, so avoid features newer than
Bash 4.4. On macOS, `/bin/bash` is 3.2; use a Homebrew Bash to test.

Each test file runs in its own Bash process with a temporary `HOME`, so tests
never touch your real configuration. To load Limon's functions without
installing the prompt (handy when writing tests):

```shell
LIMON_SOURCE_ONLY=1 source ./limon.sh
```

## What a good pull request looks like

- **One change per pull request.** Smaller pull requests get reviewed faster.
- **Add or update tests.** A bug fix should come with a test that fails
  without the fix. Put it in the matching `tests/test_*.sh` file, or add a new
  one; `tests/run.sh` picks up any `tests/test_*.sh` automatically.
- **Keep the prompt fast.** The prompt runs on every Enter. Avoid new forks
  (`$(...)`, pipes, external commands) in the render path; prefer Bash
  builtins and parameter expansion. Check with `limon bench --breakdown`.
- **Stay pure Bash.** No Python, Node.js or compiled helpers, and no
  dependency on patched fonts.
- **Update the docs.** If users can see the change, update `README.md` and the
  `limon help` text in `limon.sh`.
- **Update `CHANGELOG.md`.** Add your entry under the newest version section
  (`Added`, `Changed`, `Fixed` or `Docs`). Do **not** add an `## Unreleased`
  section: `tests/test_release.sh` rejects it and CI will fail. If you are not
  sure which version heading to use, say so in the pull request and the
  maintainer will sort it out.

### Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) style, as the
history does:

```
feat(k8s): show the namespace in the badge
fix(upgrade): switch channels on shallow installs
docs: explain update channels
```

Common types: `feat`, `fix`, `perf`, `docs`, `test`, `chore`, `ci`.

## Contributing a theme

Themes live in `themes/*.theme`. Copy an existing one, pick colors with
`limon colors`, and try it with `limon on <name>`. Mention the theme in the
README's theme list in the same pull request.

## Reporting bugs and asking for features

Use the [issue templates](https://github.com/faridrasidov/limon/issues/new/choose).
For bugs, the output of `limon version` and `limon health` saves a lot of
back-and-forth.

## License

Limon is licensed under GPL-3.0-or-later. By submitting a contribution you
agree that it is licensed under the same terms. The vendored ble.sh in
`vendor/blesh` keeps its own BSD-3-Clause license; change it only by updating
it from upstream.
