#!/usr/bin/env bash
# ==============================================================================
# chaseworkslab-dotfiles — install.sh
# Cross-platform bootstrapper: macOS + Debian/Ubuntu (Proxmox nodes)
#
# Usage:
#   git clone https://github.com/chaserbot/chaseworkslab-dotfiles.git ~/dotfiles
#   cd ~/dotfiles && bash install.sh
#
# Safe to re-run — checks before installing anything.
# ==============================================================================

set -e

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[dotfiles]${NC} $1"; }
success() { echo -e "${GREEN}[dotfiles]${NC} $1"; }
warn()    { echo -e "${YELLOW}[dotfiles]${NC} $1"; }
error()   { echo -e "${RED}[dotfiles]${NC} $1"; exit 1; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Detect OS ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ -f /etc/debian_version ]]; then
  OS="debian"
else
  error "Unsupported OS. This script supports macOS and Debian/Ubuntu only."
fi

# --- Detect CPU architecture (for Linux binary downloads) ---
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  EZA_ARCH="x86_64-unknown-linux-gnu"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  EZA_ARCH="aarch64-unknown-linux-gnu"
else
  EZA_ARCH=""
fi

info "OS: $OS | Arch: $ARCH"
echo ""

# ==============================================================================
# macOS — Homebrew installs
# ==============================================================================
if [[ "$OS" == "macos" ]]; then

  # Install Homebrew if missing
  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon Macs
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    info "Homebrew already installed — skipping."
  fi

  # Install fzf
  if ! command -v fzf &>/dev/null; then
    info "Installing fzf..."
    brew install fzf
    # Set up shell keybindings (Ctrl+R, Ctrl+T, Alt+C)
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
  else
    info "fzf already installed — skipping."
  fi

  # Install eza
  if ! command -v eza &>/dev/null; then
    info "Installing eza..."
    brew install eza
  else
    info "eza already installed — skipping."
  fi

fi

# ==============================================================================
# Debian/Ubuntu — apt + binary installs
# ==============================================================================
if [[ "$OS" == "debian" ]]; then

  # Update and install base packages
  info "Updating apt and installing base packages..."
  sudo apt-get update -qq
  sudo apt-get install -y zsh curl git fzf

  # Install eza from GitHub releases (apt version is often outdated or missing)
  if ! command -v eza &>/dev/null; then
    if [[ -n "$EZA_ARCH" ]]; then
      info "Installing eza ($EZA_ARCH)..."
      EZA_VERSION=$(curl -s https://api.github.com/repos/eza-community/eza/releases/latest \
        | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "\(.*\)".*/\1/')
      curl -Lo /tmp/eza.tar.gz \
        "https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_${EZA_ARCH}.tar.gz"
      sudo tar -xzf /tmp/eza.tar.gz -C /usr/local/bin eza
      rm /tmp/eza.tar.gz
      success "eza installed."
    else
      warn "Unknown architecture ($ARCH) — skipping eza. Install it manually."
    fi
  else
    info "eza already installed — skipping."
  fi

fi

# ==============================================================================
# Oh My Zsh
# ==============================================================================
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing Oh My Zsh..."
  # RUNZSH=no prevents auto-launching zsh mid-script
  # CHSH=no lets us handle shell switching ourselves below
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  info "Oh My Zsh already installed — skipping."
fi

# ==============================================================================
# Powerlevel10k theme
# ==============================================================================
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
  info "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  info "Powerlevel10k already installed — skipping."
fi

# ==============================================================================
# OMZ Plugins — cloned into oh-my-zsh custom/plugins
# ==============================================================================
CUSTOM_PLUGINS="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

# zsh-autosuggestions
if [[ ! -d "$CUSTOM_PLUGINS/zsh-autosuggestions" ]]; then
  info "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$CUSTOM_PLUGINS/zsh-autosuggestions"
else
  info "zsh-autosuggestions already installed — skipping."
fi

# zsh-syntax-highlighting
if [[ ! -d "$CUSTOM_PLUGINS/zsh-syntax-highlighting" ]]; then
  info "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$CUSTOM_PLUGINS/zsh-syntax-highlighting"
else
  info "zsh-syntax-highlighting already installed — skipping."
fi

# ==============================================================================
# Symlink dotfiles
# Links files from this repo into $HOME so git tracks them automatically
# ==============================================================================
info "Symlinking dotfiles..."

# Back up existing .zshrc if it's a real file (not already our symlink)
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  warn "Backing up existing .zshrc to ~/.zshrc.bak"
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi

ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
success ".zshrc symlinked → $DOTFILES_DIR/zsh/.zshrc"

# Symlink .p10k.zsh if it exists in the repo (generated by `p10k configure`)
if [[ -f "$DOTFILES_DIR/zsh/.p10k.zsh" ]]; then
  ln -sf "$DOTFILES_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
  success ".p10k.zsh symlinked."
fi

# ==============================================================================
# Set zsh as default shell
# ==============================================================================
ZSH_PATH="$(which zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  info "Setting zsh as default shell (you may be prompted for your password)..."
  # Add to /etc/shells if missing (common on Linux)
  if ! grep -qx "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
  fi
  chsh -s "$ZSH_PATH"
else
  info "zsh is already your default shell — skipping."
fi

# ==============================================================================
# Done
# ==============================================================================
echo ""
success "All done!"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo "  1. Install a Nerd Font in your terminal app:"
echo "     → macOS (iTerm2/Terminal): https://www.nerdfonts.com  (MesloLGS NF recommended)"
echo "     → Set it in: Terminal Preferences → Profile → Font"
echo "  2. Open a new terminal window."
echo "  3. The Powerlevel10k setup wizard will auto-launch on first run."
echo "     (If it doesn't: run  p10k configure)"
echo ""
echo "  To save your p10k theme after configuring it:"
echo "    cp ~/.p10k.zsh ~/dotfiles/zsh/.p10k.zsh && cd ~/dotfiles && git add -A && git commit -m 'add p10k config'"
echo ""
