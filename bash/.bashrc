# ==============================================================================
# ~/.bashrc — chaseworkslab-dotfiles (Proxmox / Debian)
# Managed via: https://github.com/chaserbot/chaseworkslab-dotfiles
# ==============================================================================

# Source system-wide defaults first (Debian sets up some basics here)
[[ -f /etc/bash.bashrc ]] && source /etc/bash.bashrc

# Not running interactively? Stop here.
[[ $- != *i* ]] && return

# ------------------------------------------------------------------------------
# Prompt
# Root gets red username (visual warning), others get green
# Shows: user@host:path [git-branch] $
# ------------------------------------------------------------------------------
parse_git_branch() {
  git branch 2>/dev/null | grep '\*' | sed 's/\* //'
}

_git_prompt() {
  local branch
  branch=$(parse_git_branch)
  [[ -n "$branch" ]] && echo " ($branch)"
}

RED='\[\033[0;31m\]'
GREEN='\[\033[0;32m\]'
YELLOW='\[\033[1;33m\]'
CYAN='\[\033[0;36m\]'
RESET='\[\033[0m\]'

if [[ $EUID -eq 0 ]]; then
  PS1="${RED}\u${RESET}@${CYAN}\h${RESET}:${YELLOW}\w${RESET}\$(_git_prompt) # "
else
  PS1="${GREEN}\u${RESET}@${CYAN}\h${RESET}:${YELLOW}\w${RESET}\$(_git_prompt) \$ "
fi

# ------------------------------------------------------------------------------
# History — bigger, no duplicates, shared across sessions
# ------------------------------------------------------------------------------
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# ------------------------------------------------------------------------------
# eza — modern ls (falls back to colorized ls if not installed)
# ------------------------------------------------------------------------------
if command -v eza &>/dev/null; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -l --icons --git --group-directories-first"
  alias la="eza -la --icons --git --group-directories-first"
  alias lt="eza --tree --icons --level=2"
  alias ltt="eza --tree --icons --level=3"
else
  alias ls="ls --color=auto"
  alias ll="ls -lh --color=auto"
  alias la="ls -lha --color=auto"
fi

# ------------------------------------------------------------------------------
# Core aliases
# ------------------------------------------------------------------------------
alias grep="grep --color=auto"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias reload="source ~/.bashrc && echo 'Shell reloaded.'"

# ------------------------------------------------------------------------------
# fzf — fuzzy history search (Ctrl+R) and file finder (Ctrl+T)
# Debian installs key-bindings separately from the binary
# ------------------------------------------------------------------------------
if command -v fzf &>/dev/null; then
  # Debian apt install location
  if [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.bash
    source /usr/share/doc/fzf/examples/completion.bash 2>/dev/null
  # git install location (~/.fzf)
  elif [[ -f ~/.fzf.bash ]]; then
    source ~/.fzf.bash
  fi
fi
