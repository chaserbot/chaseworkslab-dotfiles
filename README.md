# chaseworkslab-dotfiles

Terminal config for macOS and Debian/Ubuntu (Proxmox nodes).

**Includes:** Oh My Zsh · Powerlevel10k · zsh-autosuggestions · zsh-syntax-highlighting · fzf · eza

---

## Install (any machine)

```bash
git clone https://github.com/chaserbot/chaseworkslab-dotfiles.git ~/dotfiles
cd ~/dotfiles && bash install.sh
```

Then open a new terminal. The Powerlevel10k wizard will run on first launch — follow the prompts to pick your prompt style.

> **Requires a Nerd Font** in your terminal app for icons and prompt glyphs.
> Recommended: [MesloLGS NF](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) — download and set it in your terminal preferences.

---

## What's included

| Tool | What it does |
|---|---|
| [Oh My Zsh](https://ohmyz.sh) | Plugin/theme framework for zsh |
| [Powerlevel10k](https://github.com/romkatv/powerlevel10k) | Fast, customizable prompt with Git info |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-style suggestions from history as you type |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Commands turn green (valid) or red (invalid) before you hit enter |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy search — `Ctrl+R` for history, `Ctrl+T` for files |
| [eza](https://github.com/eza-community/eza) | Modern `ls` replacement with colors, icons, and Git status |

---

## Key aliases

| Alias | What it runs |
|---|---|
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -l --icons --git` (long list with git status) |
| `la` | `eza -la --icons --git` (long list including hidden files) |
| `lt` | `eza --tree --icons --level=2` (directory tree, 2 levels) |
| `reload` | `source ~/.zshrc` (reload config without restarting) |

---

## How it works (symlinks)

`install.sh` symlinks `zsh/.zshrc` from this repo to `~/.zshrc`. That means:
- Edits to your config = edits tracked in Git automatically
- To update any machine: `cd ~/dotfiles && git pull`

---

## Saving your Powerlevel10k theme

After running `p10k configure`, save your theme back to the repo so other machines get it:

```bash
cp ~/.p10k.zsh ~/dotfiles/zsh/.p10k.zsh
cd ~/dotfiles
git add zsh/.p10k.zsh
git commit -m "add p10k config"
git push
```

Next time you run `install.sh` on a new machine, it'll pick up your saved theme automatically.

---

## Re-running install

The script is idempotent — safe to run multiple times. Nothing gets reinstalled if it's already there.

---

## Compatibility

| Platform | Status |
|---|---|
| macOS (Apple Silicon / Intel) | ✅ |
| Debian / Ubuntu (x86\_64) | ✅ |
| Debian / Ubuntu (ARM64 — Mac Mini Proxmox nodes) | ✅ |
