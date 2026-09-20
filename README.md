# 🍋 Limon — Fast Bash Prompt with Ghost Autosuggestions, Git Status, Themes & Timer

**Limon is a fast, lightweight Bash prompt and interactive editor layer** for Linux, macOS, WSL, and Git Bash on Windows. It adds fish/Zsh-style ghost autosuggestions, 256-color themes, Git status, an execution timer, and useful indicators using Bash scripts only. There is no Python, Node.js, compiled binary, or per-architecture download.

Tired of slow shell prompts that rely on language runtimes or heavy frameworks? Hate having to install special "patched" Nerd Fonts just to see a Git branch in your prompt? Limon ships its pure-Bash editor engine and keeps prompt rendering small and measurable.

**Works on:** Linux · macOS · WSL (Windows Subsystem for Linux) · Git Bash on Windows. **Requires:** Bash 4.4 or newer and a UTF-8 terminal (Git optional, for the git branch indicator).

> **macOS note:** Apple still ships Bash 3.2 as `/bin/bash`. Install a current one with `brew install bash` and use that shell — Limon checks the version at startup and tells you if it's too old rather than failing cryptically.

![Limon bash prompt showing git branch, 256-color theme, and command execution timer in a Linux terminal](https://raw.github.com/FaridRasidov/limon/master/example.png)

---

## ✨ Features of this Fast Bash Prompt

* ⚡ **Blazing Fast:** Written purely in Bash. No Python interpreters or heavy background processes slowing down your Enter key — a truly lightweight, fast terminal prompt.
* 👻 **Ghost Autosuggestions:** History, commands, paths, aliases, functions, builtins, and loaded Bash programmable completions appear inline as you type. Right Arrow or End accepts the suggestion; Ctrl+Right accepts one word.
* 🔤 **No Patched Fonts Required:** Uses standard, universal Unicode symbols. It looks perfect out-of-the-box on any OS or font.
* 🎨 **256-Color Modular Themes:** Choose from 11 built-in themes (Limon, Dracula, Nord, Neon, and more) or easily create your own with the built-in color picker.
* ⏱️ **Smart Execution Timer:** Automatically displays how long a command took to run, with sub-second precision (`1.4s`, `2m 05s`, `1h 02m 05s`). Only appears past a threshold you set — 2 seconds by default, and `limon config timer_threshold=0.5` accepts fractions.
* 🌿 **Git Branch in Prompt:** See branch, staged/unstaged/untracked counts (`+N ~N ?N` in verbose mode), merge/rebase state, stash count (`≡N`), detached HEAD warning, and ahead/behind `(↑/↓)`.
* 🔒 **Context-Aware Directories:** Directories you don't have write access to are marked with a `🔒` and colored gray.
  * Optional root warning is available with `limon config show_root=1`.
* 🐍 **Environment Support:** Automatically detects and displays active `Python venv`, `Conda`, and `Docker` environments.

---

## 🚀 Installation (Linux, macOS, WSL & Git Bash)

### Install with one command

Paste this into your terminal and press Enter:

```shell
curl -fsSL https://raw.githubusercontent.com/faridrasidov/limon/master/get-limon.sh | bash
```

That's it. Open a new terminal and Limon is on.

**What it does:** downloads Limon into `~/.local/share/limon` and adds a few
lines to your `~/.bashrc` so the prompt loads when you open a terminal. It
touches nothing outside your home directory and never needs `sudo`. To remove
all of it later, run `limon uninstall`.

Useful options — pass them after `bash -s --`:

```shell
# Install for every user on the machine (needs sudo)
curl -fsSL https://raw.githubusercontent.com/faridrasidov/limon/master/get-limon.sh | sudo bash -s -- --system

# Install a specific release
curl -fsSL https://raw.githubusercontent.com/faridrasidov/limon/master/get-limon.sh | bash -s -- --version 1.2.0
```

> **Requires Bash 4.4 or newer.** macOS still ships Bash 3.2 as `/bin/bash`;
> install a current one with `brew install bash` and use that shell. The
> installer checks this first and tells you if your Bash is too old, rather
> than half-installing something that cannot run.

### Prefer to download it yourself?

Reasonable — piping a script into `bash` means trusting it sight unseen. Grab
the release, read it, then run it:

1. Download `limon-<version>.tar.gz` (or `.zip`) and `SHA256SUMS` from the
   [Releases page](https://github.com/faridrasidov/limon/releases).
2. Check the download is intact:
   ```shell
   sha256sum -c SHA256SUMS --ignore-missing
   ```
3. Unpack and install:
   ```shell
   tar -xzf limon-<version>.tar.gz
   bash limon-<version>/install.sh
   ```

The `.zip` is there for Git Bash on Windows, where `tar` may be missing.

### From source

Use this if you want to contribute, or to follow the `beta` / `dev` update
channels — those need a Git checkout, because `limon upgrade` tracks a branch.

```shell
git clone https://github.com/faridrasidov/limon
cd limon
bash install.sh              # add --system for all users
```

The installer is **idempotent** — re-running it (or `limon upgrade`) refreshes
the install without creating duplicate entries in your `.bashrc`.

### Manual install (alternative)

Prefer to wire it up by hand? The steps the installer automates are:

```shell
git clone https://github.com/faridrasidov/limon
sudo mv limon/ /usr/share/

echo 'alias limon="source /usr/share/limon/limon.sh"' | sudo tee -a /etc/bash.bashrc
echo 'source /usr/share/limon/hint-limon.sh' | sudo tee -a /etc/bash.bashrc
```

Then enable it:

- **For the current user:**
```shell
echo 'limon on' >> ~/.bashrc
source ~/.bashrc
```

- **For all users:**
```shell
echo 'limon on' | sudo tee -a /etc/bash.bashrc
source /etc/bash.bashrc
```

---

## ⬆️ Upgrading to 1.2.0

Your config file and themes keep working. Run `limon upgrade`, or re-run the
one-line installer. Autosuggestions are enabled by default; disable them with
`limon config autosuggest=0`.

Two things to know before you do, both covered in full in
[CHANGELOG.md](CHANGELOG.md):

- **Bash 4.4+ is now required and enforced.** If you are on macOS's stock
  `/bin/bash` (3.2), Limon will refuse to start and tell you how to fix it.
  It never really worked there — it installed the prompt but silently failed to
  save your settings.
- Limon now bundles ble.sh, adding about 2.3 MB to the install but no compiled
  binaries or architecture-specific packages.

---

## 🗑️ Uninstalling

Removing Limon is just as easy as installing it. It will **ask whether to keep or delete your configuration** so your themes and settings aren't lost by accident.

```shell
limon uninstall
```

This removes Limon's startup entries from your `.bashrc` / `/etc/bash.bashrc`, deletes the installed files, restores your original prompt in the current shell, and then prompts:

```
Remove Limon configuration directory (~/.config/limon)? [y/N]
```

Answer **N** (default) to keep your config for a future reinstall, or **y** to delete it completely.

You can also run the installer directly, which is handy for non-interactive or scripted removals:

```shell
./install.sh --uninstall              # Prompts about the config dir
./install.sh --uninstall --purge      # Remove everything, including config
./install.sh --uninstall --keep-config # Remove Limon, always keep config
```

> If Limon was installed system-wide, prefix the command with `sudo` so it can edit `/etc/bash.bashrc` and remove `/usr/share/limon`.

---

## 🛠️ Usage

Limon is designed to be completely unobtrusive. Once installed, you manage it using the `limon` command.

**Turn Limon ON (and set a theme):**

```bash
limon on          # Turns on with the default theme
limon on neon     # Switches to the 'neon' theme

```

**Turn Limon OFF (Restore system default prompt):**

```bash
limon off

```

**Other commands:**

```bash
limon status          # Show on/off, theme, and config options
limon health          # Run diagnostics (bash, colors, git, theme, prompt)
limon themes          # List all available themes
limon preview neon    # Show a sample prompt without switching themes
limon edit [theme]    # Open theme in $EDITOR (copies to ~/.config/limon/themes/)
limon reload          # Reload theme/config without toggling off
limon config git=lite    # Branch only (fast)
limon config git=verbose # Detailed +N staged, ~N modified, ?N untracked
limon config show_exit=1 # Show exit code on failure (e.g. x127 $)
limon config exit_hints=1 # Add hints like x130(SIGINT) when show_exit=1
limon config clock=1    # Show HH:MM before the command timer (off by default)
limon config timer_threshold=3    # Only show the timer past 3 seconds
limon config timer_threshold=0.5  # Fractions are allowed
limon config show_ssh=1 # Show an [ssh] tag on remote sessions (off by default)
limon config ascii=1    # Use ASCII symbols (# > ^ v) for dumb terminals
limon config max_path=40 # Truncate long paths (e.g. ~/…/project/src)
limon config env_banner=1 # Show PROD/STAGING banner when LIMON_ENV is set
limon config cloud=1    # Show AWS_PROFILE in the prompt
limon config k8s=1      # Show kubectl context (cached 2s)
limon config autosuggest=0 # Disable ghost autosuggestions (enabled by default)
limon config autosuggest_delay=150 # Delay before suggestions, in ms (0-2000)
limon config autosuggest_color=245 # Ghost text color: auto or 0-255
export LIMON_ENV=prod   # Label this shell as production (use with env_banner=1)
```

Ghost suggestions use command history first, then Bash's completion machinery
for commands, paths, aliases, functions, builtins, and command-specific
arguments. If your distribution provides `bash-completion`, load it normally in
`.bashrc`; Limon reuses those recipes instead of shipping a second copy.

Right Arrow or End accepts the whole suggestion. Ctrl+Right accepts one word.
Tab keeps its normal completion behavior. `limon off` removes Limon's prompt,
timer hooks, and editor features; an editor that you loaded yourself is left
attached with its previous configuration. A bundled ble.sh runtime already
loaded in the current Bash process stays resident but inert until the shell exits.

Colors automatically disable when `TERM=dumb` or output is not a TTY (safe for logs and `script`).

**Identity & safety:** `host_color=off` (default) keeps the theme's host color. Enable `host_color=auto` if you want each hostname to get a distinct color. `show_root=0` (default) keeps root warnings hidden; enable `show_root=1` if you want a ROOT banner. `show_sudo` warns when sudo credentials are cached.

*(Note: Limon remembers your last used theme automatically!)*

---

## 📊 Performance & Metrics

Limon is built for speed, and you can measure it. Limon can report how long it takes to render your prompt (wall-clock) and how much memory the shell is using.

**Benchmark the prompt render time:**

```bash
limon bench              # Average render time over 100 runs
limon bench 500          # More iterations for a steadier average
limon bench --breakdown  # Per-segment timings, to see where the time goes
```

Example output:

```
Limon prompt benchmark
  theme:       limon
  git mode:    full
  iterations:  100
  total:       48.300 ms
  per render:  0.483 ms (avg)
  shell RSS:   5120 KB (~5 MB, whole bash process)
  tip: most cost is the git status call; 'limon config git=lite' or 'git=off' is faster.
```

**See the live render time of each prompt:**

```bash
limon config metrics=1   # Record render time on every prompt (negligible overhead)
limon status             # Shows "Last render: 0.4xx ms" and memory usage
limon config metrics=0   # Turn it back off (default)
```

`limon health` also includes a quick render-time and memory line.

**Where the time goes:**

```
$ limon bench --breakdown
Limon prompt benchmark — per segment
  theme: default, git mode: full, 200 iterations each

  theme (cached)         0.068 ms
  git info               0.065 ms
  safety prefix          0.032 ms
  path                   0.020 ms
  prompt symbol          0.028 ms
  host color             0.014 ms
  symbols                0.014 ms

  segments total         0.241 ms
  whole render           0.363 ms
```

> **Notes:**
> - Render time is **wall-clock** time spent building the prompt. Sub-millisecond precision needs **bash 5+** (uses `$EPOCHREALTIME`, no subprocess) or **GNU `date`**.
> - The memory figure is the **whole bash process** RSS (read from `/proc/$$/status` on Linux, or `ps` elsewhere), not Limon in isolation — Limon adds no background processes of its own.
> - The biggest factor in render time is the `git` status call. Use `limon config git=lite` (branch only) or `git=off` to speed up huge repositories.

---

## 🔄 Updating Limon

Limon installs as a small Git repository, so updating to the latest version is built in.

**Update manually (recommended):**

```bash
limon upgrade
```

This runs a safe fast-forward `git pull` in your Limon install directory and tells you when it's done. After updating, run `limon on` (or open a new terminal) to load the new version.

See [CHANGELOG.md](CHANGELOG.md) for notable changes in each release.

> If Limon is installed in a system directory like `/usr/share/limon`, you may need elevated permissions. Limon will detect this and suggest:
> ```bash
> sudo git -C /usr/share/limon pull --ff-only
> ```

**Enable automatic update checks:**

```bash
limon config autoupdate=notify   # Check once a day, notify you when an update exists
limon config autoupdate=on        # Check once a day, auto-install updates when possible
limon config autoupdate=off       # Disable update checks (default)
```

Update checks are **throttled to once per day** and run **in the background**, so they never slow down your prompt. When an update is available you'll see a short notice the next time you start a shell.

### Update channels (stable, beta, dev)

Limon tracks one of three branches, so you can choose how new (and how risky) your updates are:

| Channel | Branch | Description |
|---------|--------|-------------|
| `stable` | `master` | Tested, recommended for everyday use (**default**) |
| `beta` | `beta` | Newest features, **may be unstable** |
| `dev` | `dev` | Active development, expect breakage |

```bash
limon upgrade           # Update on your current channel
limon upgrade beta      # Switch to the beta channel and update
limon upgrade stable    # Switch back to the stable channel and update
limon upgrade dev       # Switch to the bleeding-edge dev channel and update
```

Switching channels is remembered, so future `limon upgrade` runs (and the auto-update checks) stay on the channel you chose. To change the channel **without** upgrading right away:

```bash
limon config channel=beta   # Next 'limon upgrade' will move you to beta
```

`limon status` shows your current channel and the git branch it maps to. To return to stable releases at any time, run `limon upgrade stable`.

---

## 🎨 Custom Bash Prompt Themes & Customization

Limon supports massive customization of your bash prompt through simple `.theme` files. Themes are stored in `~/.config/limon/themes/`.

**Edit a theme in your editor:**

```bash
limon edit neon        # Copies built-in theme to ~/.config/limon/themes/ if needed, then opens $EDITOR
limon edit             # Edits the current theme
```

**Preview without switching:**

```bash
limon preview dracula  # Prints a sample prompt using that theme
```

### Built-in Themes

Run `limon themes` to see every theme on your system. Apply any theme with `limon on <name>`.

| Theme | Style | Layout |
|-------|-------|--------|
| `default` | Teal, blue, green | Single-line |
| `limon` | Yellow-green brand colors | Two-line `➜` |
| `neon` | Hot pink, cyan, yellow | Single-line |
| `sunset` | Orange, gold, warm reds | Two-line `➜` |
| `ocean` | Blues and pale cyan | Single-line ` \| ` |
| `forest` | Greens and brown timer | Single-line |
| `dracula` | Purple, pink, cyan | Two-line `➜` |
| `nord` | Muted frost blues and snow | Single-line ` \| ` |
| `mono` | Grayscale (SSH-friendly) | Single-line |
| `high-contrast` | Bold green, red, yellow, white | Single-line |
| `git_bash` | Cyan and gold (Windows Git Bash) | Two-line `➜` |

**Preview (structure only — colors appear in your terminal):**

```
# limon on default
user@host:/path/to/project (@) [main] $

# limon on limon
user@host /path/to/project (@) [main]
➜ $

# limon on dracula
user@host /path/to/project (@) [main]
➜ $

# limon on nord
user@host | /path/to/project (@) [main] $
```

### Finding Colors

Don't know the ANSI code for "Hot Pink" or "Deep Blue"? Limon has a built-in color palette generator. Run:

```bash
limon colors

```

This will print a grid of all 256 available colors directly in your terminal with their corresponding ID numbers.

### Creating a Custom Theme

1. Create a new file: `nano ~/.config/limon/themes/my_theme.theme`
2. Define your colors and layout using the 256-color syntax (`\e[38;5;Nm` where `N` is the color number):

```bash
# my_theme.theme

col_ok='\[\e[38;5;46m\]'      # Neon Green for success
col_err='\[\e[38;5;196m\]'    # Red for errors
col_git='\[\e[38;5;214m\]'    # Orange for Git
col_dir='\[\e[38;5;39m\]'     # Blue for paths
col_host='\[\e[38;5;118m\]'   # Green for user@host
col_time='\[\e[38;5;242m\]'   # Grey for the timer

theme_multiline=0             # Set to 1 for a two-line prompt
theme_separator=":"           # Character between host and path
theme_symbol_prefix="➜ "      # Symbol right before your typing area
theme_max_path=0              # Truncate long paths (0 = use bash \w; e.g. 40)

```

3. Apply it: `limon on my_theme`

---

## 🤔 Why Limon? (The Philosophy)

Modern prompt customization tools are incredibly powerful, but they often rely on external binaries or interpreted languages (like Python). Invoking these interpreters every single time you hit `Enter` introduces a noticeable micro-delay. **Delay sucks.**

Furthermore, many popular prompts force you to install specific "Nerd Fonts" to render their custom glyphs. If you use a simple bitmap font or log into a remote server, those icons break into ugly missing-character boxes.

Limon was built to solve these two problems. It gives you the colorful, Git-aware, and timer-equipped prompt you want, but does it instantly, natively, and beautifully on any system.

---

## ⚖️ Limon vs. Alternatives (Starship, Powerlevel10k, Oh My Posh)

If you've looked at customizing your shell prompt before, you've probably seen tools like **Starship**, **Powerlevel10k**, **Oh My Posh**, or **bash-git-prompt**. They are excellent and feature-rich, but they generally:

* Require an external binary or interpreter (Rust, Go, Python, Node.js) to be installed and invoked on every prompt.
* Often expect you to install **Nerd Fonts** to render their custom glyphs and icons.

**Limon is a lightweight, Bash-native alternative.** It bundles the pure-Bash ble.sh line editor, uses ordinary Unicode symbols, and needs no separate runtime or patched font. Optional Git powers repository status; optional system `bash-completion` adds richer command-specific suggestions.

---

## ❓ FAQ

**How do I add the Git branch to my Bash prompt?**
Install Limon and run `limon on`. It automatically detects Git repositories and shows your current branch, plus indicators for uncommitted changes `(@)`, untracked files `(?)`, and commits ahead/behind the remote `(↑/↓)`.

**What is the fastest Bash prompt?**
Limon is written in pure Bash with no external interpreters, so there is no per-prompt startup cost from Python, Node.js, or a separate binary. This makes it one of the fastest, most lightweight ways to get a colorful, Git-aware prompt.

**How can I measure how fast (or heavy) my prompt is?**
Run `limon bench` to see the average render time over many runs, plus the shell's memory usage. For a live per-prompt reading, enable `limon config metrics=1` and check `limon status`. See [Performance & Metrics](#-performance--metrics) for details.

**Do I need Nerd Fonts for a colored prompt?**
No. Limon uses only standard, universal Unicode symbols and 256-color ANSI codes, so it looks correct out-of-the-box on any OS, terminal, or font — no patched Nerd Fonts required.

**How do I customize PS1 in my `.bashrc`?**
Add `limon on` to your `~/.bashrc` (or `/etc/bash.bashrc` for all users). Limon sets `PS1` for you and remembers your last theme. You can further customize the prompt with simple `.theme` files — see [Custom Bash Prompt Themes](#-custom-bash-prompt-themes--customization).

**Does Limon work on Windows (WSL / Git Bash)?**
Yes. Limon runs on Linux, macOS, WSL (Windows Subsystem for Linux), and Git Bash on Windows. There's even a built-in `git_bash` theme tuned for the Git Bash terminal. The editor is pure Bash, so there is no Windows-specific executable.

**How do I show command execution time in the prompt?**
Limon includes a built-in execution timer that automatically shows how long a command took (by default only when it runs longer than 2 seconds). Adjust it with `limon config timer_threshold=N`.

**How do I update Limon to the latest version?**
Run `limon upgrade`. Since Limon is installed as a Git repository, this performs a safe fast-forward update from the channel you're on (stable by default). You can also enable automatic daily update checks with `limon config autoupdate=notify` or `limon config autoupdate=on`.

**How do I try beta/development features?**
Limon has three update channels mapped to git branches: `stable` (master), `beta` (newest features, may be unstable), and `dev` (bleeding edge). Run `limon upgrade beta` to switch to and update on the beta channel, or `limon upgrade stable` to switch back. The choice is remembered for future updates.

**How do I remove or disable Limon?**
To temporarily disable it, run `limon off` to instantly restore your system's default prompt. To uninstall it completely, run `limon uninstall` (or `./install.sh --uninstall`) — it removes the startup entries and installed files, and asks whether to keep or delete your `~/.config/limon` configuration.

---

## 🧪 Development & Testing

Limon ships a dependency-free test suite written in plain Bash — no `bats`, no package manager, nothing to install.

```shell
bash tests/run.sh              # run everything
bash tests/run.sh git          # run only files matching "git"
bash tests/bench_guard.sh      # check prompt render time against a ceiling
```

Each test file runs in its own Bash process with an isolated `HOME` and `XDG_CONFIG_HOME`, so your real configuration and themes are never touched.

Linting uses [ShellCheck](https://www.shellcheck.net/):

```shell
shellcheck -S warning limon.sh install.sh hint-limon.sh tests/*.sh
```

Both run automatically in CI on every push and pull request, across Bash 4.4, 5.0, 5.2, and 5.3. CI also uses a real pseudo-terminal to accept a rendered ghost suggestion.

To load Limon's functions without installing the prompt (useful when writing tests):

```shell
LIMON_SOURCE_ONLY=1 source ./limon.sh
```

---

## 🏷️ GitHub Topics

To help others discover this project, the repository uses topics such as:
`bash` · `shell` · `prompt` · `bash-prompt` · `ps1` · `git` · `terminal` · `cli` · `linux` · `macos` · `wsl` · `git-bash` · `themes` · `dotfiles` · `bashrc`

---

## 📄 License

Limon is free software, licensed under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later).

You are free to use, modify, and distribute this project under the terms of the GPL. See the [LICENSE](LICENSE) file for the full license text.

The bundled ble.sh runtime is BSD-3-Clause licensed. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and
[`vendor/blesh/LICENSE.md`](vendor/blesh/LICENSE.md).

---

### Contributions

Ideas, bug reports, and new themes are always welcome! Feel free to open an issue or submit a Pull Request.

**Peace ✌️**
