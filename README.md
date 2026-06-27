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
* 🌿 **Git Branch in Prompt:** Instantly see your current Git branch, uncommitted changes `(@)`, untracked files `(?)`, and commits ahead/behind remote `(↑/↓)` — git branch status right in your bash prompt.
* 🔒 **Context-Aware Directories:** * Directories you don't have write access to are marked with a `🔒` and colored gray.
  * Warns you visually when operating as the `root` user outside of safe directories.
* 🐍 **Environment Support:** Automatically detects and displays active `Python venv`, `Conda`, and `Docker` environments.

---

## 🚀 Installation (Linux, macOS, WSL & Git Bash)

**1. Download the repository:**
```shell
git clone https://github.com/faridrasidov/limon

sudo mv limon/ /usr/share/

echo 'export TERM=xterm-256color' | sudo tee -a /etc/bash.bashrc
echo 'alias limon="source /usr/share/limon/limon.sh"' | sudo tee -a /etc/bash.bashrc
echo 'source /usr/share/limon/hint-limon.sh' | sudo tee -a /etc/bash.bashrc
```
**2. Enabling Limon** 
- **Enable For Current User**
```shell
echo 'limon on' >> ~/.bashrc
source ~/.bashrc
```

- **Enable For All Users**
```shell
echo 'limon on' | sudo tee -a /etc/bash.bashrc
source /etc/bash.bashrc
```

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
limon themes          # List all available themes
limon reload          # Reload theme/config without toggling off
limon config git=lite # Set git mode: full, lite, or off
limon config timer_threshold=3
```

*(Note: Limon remembers your last used theme automatically!)*

---

## 🎨 Custom Bash Prompt Themes & Customization

Limon supports massive customization of your bash prompt through simple `.theme` files. Themes are stored in `~/.config/limon/themes/`.

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

**Do I need Nerd Fonts for a colored prompt?**
No. Limon uses only standard, universal Unicode symbols and 256-color ANSI codes, so it looks correct out-of-the-box on any OS, terminal, or font — no patched Nerd Fonts required.

**How do I customize PS1 in my `.bashrc`?**
Add `limon on` to your `~/.bashrc` (or `/etc/bash.bashrc` for all users). Limon sets `PS1` for you and remembers your last theme. You can further customize the prompt with simple `.theme` files — see [Custom Bash Prompt Themes](#-custom-bash-prompt-themes--customization).

**Does Limon work on Windows (WSL / Git Bash)?**
Yes. Limon runs on Linux, macOS, WSL (Windows Subsystem for Linux), and Git Bash on Windows. There's even a built-in `git_bash` theme tuned for the Git Bash terminal.

**How do I show command execution time in the prompt?**
Limon includes a built-in execution timer that automatically shows how long a command took (by default only when it runs longer than 2 seconds). Adjust it with `limon config timer_threshold=N`.

**How do I remove or disable Limon?**
Run `limon off` to instantly restore your system's default prompt. To disable it permanently, remove the `limon on` line from your `.bashrc`.

---

## 🏷️ GitHub Topics

To help others discover this project, the repository uses topics such as:
`bash` · `shell` · `prompt` · `bash-prompt` · `ps1` · `git` · `terminal` · `cli` · `linux` · `macos` · `wsl` · `git-bash` · `themes` · `dotfiles` · `bashrc`

---

### Contributions

Ideas, bug reports, and new themes are always welcome! Feel free to open an issue or submit a Pull Request.

**Peace ✌️**
