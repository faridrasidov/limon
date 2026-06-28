# 🍋 Limon — Fast Bash Prompt with Git Status, Themes & Timer (Pure Bash, No Nerd Font)

**Limon is a fast, lightweight Bash prompt** for Linux, macOS, WSL, and Git Bash on Windows. It instantly upgrades your terminal prompt (PS1) with beautiful 256-colors, Git branch status, an execution timer, and helpful indicators — using **pure Bash** with no Python, Node.js, or external dependencies.

Tired of slow shell prompts that rely on Python, Node.js, or heavy frameworks? Hate having to install special "patched" Nerd Fonts just to see a Git branch in your prompt? Limon is built differently. It uses built-in Bash features to deliver a beautiful, informative, and **zero-delay** custom bash prompt experience — perfect for customizing your `.bashrc` / `bashrc` prompt on any system.

**Works on:** Linux · macOS · WSL (Windows Subsystem for Linux) · Git Bash on Windows. **Requires:** Bash (Git optional, for the git branch indicator).

![Limon bash prompt showing git branch, 256-color theme, and command execution timer in a Linux terminal](https://raw.github.com/FaridRasidov/limon/master/example.png)

---

## ✨ Features of this Fast Bash Prompt

* ⚡ **Blazing Fast:** Written purely in Bash. No Python interpreters or heavy background processes slowing down your Enter key — a truly lightweight, fast terminal prompt.
* 🔤 **No Patched Fonts Required:** Uses standard, universal Unicode symbols. It looks perfect out-of-the-box on any OS or font.
* 🎨 **256-Color Modular Themes:** Choose from 11 built-in themes (Limon, Dracula, Nord, Neon, and more) or easily create your own with the built-in color picker.
* ⏱️ **Smart Execution Timer:** Automatically displays how long a command took to run (only appears if the command takes longer than 2 seconds).
* 🌿 **Git Branch in Prompt:** See branch, staged/unstaged/untracked counts (`+N ~N ?N` in verbose mode), merge/rebase state, stash count (`≡N`), detached HEAD warning, and ahead/behind `(↑/↓)`.
* 🔒 **Context-Aware Directories:** * Directories you don't have write access to are marked with a `🔒` and colored gray.
  * Warns you visually when operating as the `root` user outside of safe directories.
* 🐍 **Environment Support:** Automatically detects and displays active `Python venv`, `Conda`, and `Docker` environments.

---

## 🚀 Installation (Linux, macOS, WSL & Git Bash)

### Quick install (recommended)

The included `install.sh` script copies Limon into place and wires it into your shell startup automatically.

```shell
git clone https://github.com/faridrasidov/limon
cd limon

# Install for the current user (no sudo needed):
bash install.sh

# ...or install system-wide for all users:
sudo bash install.sh --system
```

Then open a new terminal (or `source ~/.bashrc`) and Limon is on. The installer is **idempotent** — re-running it (or `limon upgrade`) safely refreshes the install without creating duplicate entries.

### Manual install (alternative)

Prefer to do it by hand? The steps the installer automates are:

```shell
git clone https://github.com/faridrasidov/limon
sudo mv limon/ /usr/share/

echo 'export TERM=xterm-256color' | sudo tee -a /etc/bash.bashrc
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
limon config timer_threshold=3
limon config show_ssh=1 # Show an [ssh] tag on remote sessions (off by default)
limon config ascii=1    # Use ASCII symbols (# > ^ v) for dumb terminals
limon config max_path=40 # Truncate long paths (e.g. ~/…/project/src)
limon config env_banner=1 # Show PROD/STAGING banner when LIMON_ENV is set
limon config cloud=1    # Show AWS_PROFILE in the prompt
limon config k8s=1      # Show kubectl context (cached 2s)
export LIMON_ENV=prod   # Label this shell as production (use with env_banner=1)
```

Colors automatically disable when `TERM=dumb` or output is not a TTY (safe for logs and `script`).

**Identity & safety:** `host_color=auto` (default) gives each hostname a distinct color. `show_root` and `show_sudo` warn when running as root or when sudo credentials are cached.

*(Note: Limon remembers your last used theme automatically!)*

---

## 📊 Performance & Metrics

Limon is built for speed, and you can measure it. Limon can report how long it takes to render your prompt (wall-clock) and how much memory the shell is using.

**Benchmark the prompt render time:**

```bash
limon bench        # Average render time over 100 runs
limon bench 500    # More iterations for a steadier average
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

**Limon is a lightweight, pure-Bash alternative.** It has zero external dependencies (beyond optional Git), uses only universal Unicode symbols, and adds no measurable delay when you press `Enter`. If you want a fast bash prompt with git status and themes without installing a separate runtime or patched fonts, Limon is for you.

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
Yes. Limon runs on Linux, macOS, WSL (Windows Subsystem for Linux), and Git Bash on Windows. There's even a built-in `git_bash` theme tuned for the Git Bash terminal.

**How do I show command execution time in the prompt?**
Limon includes a built-in execution timer that automatically shows how long a command took (by default only when it runs longer than 2 seconds). Adjust it with `limon config timer_threshold=N`.

**How do I update Limon to the latest version?**
Run `limon upgrade`. Since Limon is installed as a Git repository, this performs a safe fast-forward update from the channel you're on (stable by default). You can also enable automatic daily update checks with `limon config autoupdate=notify` or `limon config autoupdate=on`.

**How do I try beta/development features?**
Limon has three update channels mapped to git branches: `stable` (master), `beta` (newest features, may be unstable), and `dev` (bleeding edge). Run `limon upgrade beta` to switch to and update on the beta channel, or `limon upgrade stable` to switch back. The choice is remembered for future updates.

**How do I remove or disable Limon?**
To temporarily disable it, run `limon off` to instantly restore your system's default prompt. To uninstall it completely, run `limon uninstall` (or `./install.sh --uninstall`) — it removes the startup entries and installed files, and asks whether to keep or delete your `~/.config/limon` configuration.

---

## 🏷️ GitHub Topics

To help others discover this project, the repository uses topics such as:
`bash` · `shell` · `prompt` · `bash-prompt` · `ps1` · `git` · `terminal` · `cli` · `linux` · `macos` · `wsl` · `git-bash` · `themes` · `dotfiles` · `bashrc`

---

## 📄 License

Limon is free software, licensed under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later).

You are free to use, modify, and distribute this project under the terms of the GPL. See the [LICENSE](LICENSE) file for the full license text.

---

### Contributions

Ideas, bug reports, and new themes are always welcome! Feel free to open an issue or submit a Pull Request.

**Peace ✌️**
