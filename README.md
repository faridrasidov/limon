# 🍋 Limon - Fast, Pure Bash Color Prompt

**Limon** is a lightweight, pure Bash script designed to instantly upgrade your terminal prompt (PS1) with beautiful colors, Git status, and helpful indicators. 

Tired of slow terminal prompts that rely on Python, Node.js, or heavy frameworks? Hate having to install special "patched" Nerd Fonts just to see a Git branch? Limon is built differently. It uses built-in Bash features to deliver a beautiful, informative, and **zero-delay** terminal experience.

![Limon Example Prompt](https://raw.github.com/FaridRasidov/limon/master/example.png)

---

## ✨ Features

* ⚡ **Blazing Fast:** Written purely in Bash. No Python interpreters or heavy background processes slowing down your Enter key.
* 🔤 **No Patched Fonts Required:** Uses standard, universal Unicode symbols. It looks perfect out-of-the-box on any OS or font.
* 🎨 **256-Color Modular Themes:** Choose from built-in themes (Neon, Sunset, Ocean, etc.) or easily create your own with the built-in color picker.
* ⏱️ **Smart Execution Timer:** Automatically displays how long a command took to run (only appears if the command takes longer than 2 seconds).
* 🌿 **Git Integration:** Instantly see your current branch, uncommitted changes `(@)`, untracked files `(?)`, and commits ahead/behind remote `(↑/↓)`.
* 🔒 **Context-Aware Directories:** * Directories you don't have write access to are marked with a `🔒` and colored gray.
  * Warns you visually when operating as the `root` user outside of safe directories.
* 🐍 **Environment Support:** Automatically detects and displays active `Python venv`, `Conda`, and `Docker` environments.

---

## 🚀 Installation

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

*(Note: Limon remembers your last used theme automatically!)*

---

## 🎨 Themes & Customization

Limon supports massive customization through simple `.theme` files. Themes are stored in `~/.config/limon/themes/`.

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

### Contributions

Ideas, bug reports, and new themes are always welcome! Feel free to open an issue or submit a Pull Request.

**Peace ✌️**
