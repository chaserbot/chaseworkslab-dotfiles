# ==============================================================================
# ~/.zshrc — chaseworkslab-dotfiles
# Managed via: https://github.com/chaserbot/chaseworkslab-dotfiles
# To re-run setup: bash install.sh from the repo root
# ==============================================================================

# Powerlevel10k instant prompt — keeps terminal snappy on load.
# Must stay near the top of .zshrc. Nothing that writes to stdout above this.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# Oh My Zsh
# ------------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  fzf
)

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# ------------------------------------------------------------------------------
# eza — modern ls replacement
# Falls back to colorized ls if eza isn't installed yet
# ------------------------------------------------------------------------------
if command -v eza &>/dev/null; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -l --icons --git --group-directories-first"
  alias la="eza -la --icons --git --group-directories-first"
  alias lt="eza --tree --icons --level=2"
  alias ltt="eza --tree --icons --level=3"
else
  # Fallback: colorized ls
  alias ll="ls -lh"
  alias la="ls -lha"
fi

# ------------------------------------------------------------------------------
# Navigation shortcuts
# ------------------------------------------------------------------------------
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias reload="source ~/.zshrc && echo 'Shell reloaded.'"

# ------------------------------------------------------------------------------
# Powerlevel10k config
# Run `p10k configure` any time to redo the wizard
# ------------------------------------------------------------------------------
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
