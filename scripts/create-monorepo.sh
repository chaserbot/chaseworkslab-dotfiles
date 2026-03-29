#!/usr/bin/env bash
# ==============================================================================
# chaseworkslab — create-monorepo.sh
# Consolidates all chaseworkslab-* repos into a single monorepo with full
# git history preserved for each subfolder.
#
# Usage:
#   bash scripts/create-monorepo.sh
#
# Override defaults:
#   MONOREPO_DIR=~/workspace/chaseworkslab bash scripts/create-monorepo.sh
#
# Safe to re-run — already-imported subfolders are skipped automatically.
# Requires: git >= 2.23  (optionally: gh CLI for auto GitHub push)
# ==============================================================================

set -euo pipefail

# ==============================================================================
# Configuration — edit these if needed
# ==============================================================================
MONOREPO_DIR="${MONOREPO_DIR:-$HOME/chaseworkslab}"
GITHUB_USER="chaserbot"
MONOREPO_REPO_NAME="chaseworkslab"
MONOREPO_DESCRIPTION="chaserbot homelab monorepo — infrastructure, configs, and tooling"
GITHUB_BASE="https://github.com/${GITHUB_USER}"

# ==============================================================================
# Colors and logging (matching install.sh conventions)
# ==============================================================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[monorepo]${NC} $1"; }
success() { echo -e "${GREEN}[monorepo]${NC} $1"; }
warn()    { echo -e "${YELLOW}[monorepo]${NC} $1"; }
error()   { echo -e "${RED}[monorepo]${NC} $*"; exit 1; }

# ==============================================================================
# Section 1: Preflight checks
# ==============================================================================
preflight() {
  info "Running preflight checks..."

  # Require git
  if ! command -v git &>/dev/null; then
    error "git is not installed. Install git and re-run."
  fi

  # Warn if MONOREPO_DIR exists but is NOT a git repo (unexpected state)
  if [[ -d "$MONOREPO_DIR" && ! -d "$MONOREPO_DIR/.git" ]]; then
    error "$MONOREPO_DIR already exists and is not a git repo. Remove it or set MONOREPO_DIR to a different path."
  fi

  # Resume mode notice
  if [[ -d "$MONOREPO_DIR/.git" ]]; then
    warn "$MONOREPO_DIR already exists as a git repo — resuming in idempotent mode."
    warn "Already-imported subfolders will be skipped."
  fi

  success "Preflight passed."
  echo ""
}

# ==============================================================================
# Section 2: Initialize monorepo
# ==============================================================================
init_monorepo() {
  if [[ -d "$MONOREPO_DIR/.git" ]]; then
    info "Monorepo already initialized — skipping init."
    return 0
  fi

  info "Creating monorepo at $MONOREPO_DIR..."
  mkdir -p "$MONOREPO_DIR"
  cd "$MONOREPO_DIR"

  # Init with main branch (git >= 2.28 supports -b; fall back gracefully)
  if git init -b main &>/dev/null 2>&1; then
    git init -b main
  else
    git init
    git checkout -b main 2>/dev/null || true
  fi

  # Root .gitignore
  cat > .gitignore << 'EOF'
.DS_Store
*.swp
*~
.env
.env.*
!.env.example
node_modules/
__pycache__/
*.pyc
.vagrant/
*.log
EOF

  git add .gitignore
  git commit -m "chore: init monorepo with root .gitignore"
  success "Monorepo initialized."
  echo ""
}

# ==============================================================================
# Section 3: Import a single repo into a subfolder with history preserved
#
# Usage: import_repo <repo-name> <subfolder>
#
# The core technique (pure git, no extra tools):
#   1. Add remote, fetch
#   2. git merge -s ours --no-commit --allow-unrelated-histories
#   3. git read-tree --prefix=<subfolder>/ -u <remote>/<branch>
#   4. git commit
#   5. Remove remote
# ==============================================================================
import_repo() {
  local repo_name="$1"
  local subfolder="$2"
  local remote_url="${GITHUB_BASE}/${repo_name}.git"

  cd "$MONOREPO_DIR"

  # Idempotency guard — skip if subfolder already has commits
  if [[ -d "$subfolder" ]] && git log --oneline -- "$subfolder" 2>/dev/null | grep -q .; then
    warn "  $subfolder/ already imported — skipping $repo_name."
    return 0
  fi

  info "  Importing $repo_name -> $subfolder/ ..."

  # Resolve branch name: probe for main, fall back to master
  local resolved_branch=""
  if git ls-remote --heads "$remote_url" main 2>/dev/null | grep -q "refs/heads/main"; then
    resolved_branch="main"
  elif git ls-remote --heads "$remote_url" master 2>/dev/null | grep -q "refs/heads/master"; then
    resolved_branch="master"
  else
    # Check if repo is reachable at all
    if ! git ls-remote "$remote_url" &>/dev/null; then
      error "  Cannot reach $remote_url — check network and repo access."
    fi
    error "  $repo_name has neither a 'main' nor 'master' branch. Inspect manually."
  fi

  # Remote collision guard — remove stale remote if it exists (e.g. from a prior partial run)
  if git remote | grep -q "^${repo_name}$"; then
    warn "  Stale remote '${repo_name}' found — removing before re-adding."
    git remote remove "$repo_name"
  fi

  # Add remote and fetch
  git remote add "$repo_name" "$remote_url"
  git fetch "$repo_name" --no-tags

  # Merge scaffold: ours strategy creates a merge commit without touching the working tree
  git merge -s ours --no-commit --allow-unrelated-histories "${repo_name}/${resolved_branch}"

  # Read the remote's tree into the subfolder
  git read-tree --prefix="${subfolder}/" -u "${repo_name}/${resolved_branch}"

  # Commit with clear attribution
  git commit -m "chore: import ${repo_name} into ${subfolder}/"

  # Clean up remote (history is already baked into the monorepo)
  git remote remove "$repo_name"

  success "  Imported $repo_name -> $subfolder/"
  echo ""
}

# ==============================================================================
# Section 4: Write LLM context and memory files
# ==============================================================================
write_context_files() {
  cd "$MONOREPO_DIR"

  info "Writing context and memory files..."

  # --------------------------------------------------------------------------
  # README.md
  # --------------------------------------------------------------------------
  cat > README.md << 'EOF'
# chaseworkslab

Monorepo for all chaserbot homelab infrastructure, configs, and tooling.

## Structure

| Folder | Source Repo | Description |
|--------|-------------|-------------|
| dotfiles/ | chaseworkslab-dotfiles | Terminal config — zsh, Oh My Zsh, Powerlevel10k, bash |
| llm/ | chaseworkslab-llm | Self-hosted LLM stack (Ollama, Open WebUI, etc.) |
| docker/ | chaseworkslab-docker | Docker Compose stacks for homelab services |
| ansible/ | chaseworkslab-ansible | Ansible playbooks for provisioning and config management |
| proxmox/ | chaseworkslab-proxmox | Proxmox host configuration, docs, and post-install scripts |
| arr/ | chaseworkslab-arr | Arr stack configs and compose files (Sonarr, Radarr, Prowlarr, etc.) |
| monitoring/ | chaseworkslab-monitoring | Grafana and Prometheus monitoring stack |
| lxc/ | chaseworkslab-lxc | LXC container templates and configs for Proxmox |
| inventory/ | chaseworkslab-inventory | Homelab network inventory — hosts, IPs, services, ports |
| homelab-context/ | homelab-context | Homelab context and reference documentation |

## Git history

All commit history from each source repository has been preserved.
To inspect history for a specific subfolder:

    git log --oneline -- dotfiles/
    git log --oneline -- ansible/
    git log --follow -- proxmox/post-install.sh

## Quick start on a new machine

    git clone https://github.com/chaserbot/chaseworkslab.git ~/chaseworkslab

Then navigate to whichever subfolder you need and follow its README.

## Context files for AI tools

This repo includes a set of context and memory files designed to onboard any LLM
without requiring it to scan the full codebase from scratch:

| File | Purpose |
|------|---------|
| AGENTS.md | Project rules and behavioral guidelines for AI agents |
| CLAUDE.md | Claude-specific guidance and environment assumptions |
| STACK.md | Full service, port, and tool inventory |
| CURRENT_STATE.md | What is running, what is stable, last-known-good state |
| NEXT_STEPS.md | Planned work, in-progress tasks, and ideas backlog |
| DECISIONS.md | Architectural decision log |

## Migration

This monorepo was created using `scripts/create-monorepo.sh` from
[chaseworkslab-dotfiles](https://github.com/chaserbot/chaseworkslab-dotfiles).
EOF

  # --------------------------------------------------------------------------
  # AGENTS.md
  # --------------------------------------------------------------------------
  cat > AGENTS.md << 'EOF'
# Project rules

- This repo manages Chase's homelab.
- Prefer Docker Compose for app services unless there is a strong reason otherwise.
- Proxmox hosts should be documented before changes are applied.
- Never hardcode secrets in yaml or shell scripts.
- When changing ports, also update STACK.md.
- After any meaningful change:
  1. update CURRENT_STATE.md
  2. add an entry to DECISIONS.md
  3. suggest rollback steps

## Repo structure

Each subfolder maps to what was previously a standalone GitHub repo.
See README.md for the full folder-to-repo mapping.

## Working with secrets

Use environment variables or `.env` files (gitignored) for all credentials.
Reference `.env.example` files for required variable names without values.
Never commit `.env`, API keys, passwords, or tokens.

## Branching

Work in feature branches. Keep `main` stable and deployable.
EOF

  # --------------------------------------------------------------------------
  # CLAUDE.md
  # --------------------------------------------------------------------------
  cat > CLAUDE.md << 'EOF'
# Claude project guidance

Focus on:
- explaining infra changes clearly
- minimizing risky destructive actions
- proposing step-by-step rollout plans
- updating docs after edits

Assume:
- mixed environment of Mac mini, Proxmox, Docker, SMB mounts, Tailscale
- user prefers practical, conversational explanations

## Doc maintenance

After any meaningful change to infrastructure or configs, update:
- CURRENT_STATE.md (what changed, new state)
- DECISIONS.md (why the change was made)
- STACK.md (if ports or services changed)
- NEXT_STEPS.md (check off completed items, add follow-ups)

## Risk posture

- Before destructive operations, confirm with the user
- Prefer additive changes over modifications to working configs
- When proposing a rollback, make it concrete and copy-pasteable
EOF

  # --------------------------------------------------------------------------
  # STACK.md
  # --------------------------------------------------------------------------
  cat > STACK.md << 'EOF'
# Stack

Complete inventory of services, tools, and ports running in the homelab.
Update this file whenever a service is added, removed, or its port changes.

## Infrastructure

| Component | Role | Notes |
|-----------|------|-------|
| Mac mini | Primary workstation / media server | macOS |
| Proxmox node(s) | Hypervisor | See proxmox/ subfolder |
| Tailscale | VPN / zero-trust networking | Connects all nodes |
| SMB | File sharing | Mounted on relevant hosts |

## Services and ports

| Service | Folder | Port(s) | Host | Notes |
|---------|--------|---------|------|-------|
| Open WebUI | llm/ | <!-- port --> | <!-- host --> | LLM frontend |
| Ollama | llm/ | <!-- port --> | <!-- host --> | Local LLM backend |
| Grafana | monitoring/ | <!-- port --> | <!-- host --> | Dashboards |
| Prometheus | monitoring/ | <!-- port --> | <!-- host --> | Metrics |
| Sonarr | arr/ | <!-- port --> | <!-- host --> | TV automation |
| Radarr | arr/ | <!-- port --> | <!-- host --> | Movie automation |
| Prowlarr | arr/ | <!-- port --> | <!-- host --> | Indexer management |
| <!-- service --> | docker/ | <!-- port --> | <!-- host --> | <!-- notes --> |

## Tools

| Tool | Purpose | Installed on |
|------|---------|-------------|
| Docker + Compose | Container runtime | Proxmox LXC / nodes |
| Ansible | Config management | Mac mini (control node) |
| fzf | Fuzzy finder | All machines (via dotfiles) |
| eza | ls replacement | All machines (via dotfiles) |
| Oh My Zsh + Powerlevel10k | Shell | macOS only (via dotfiles) |
EOF

  # --------------------------------------------------------------------------
  # CURRENT_STATE.md
  # --------------------------------------------------------------------------
  cat > CURRENT_STATE.md << 'EOF'
# Current state

Last updated: <!-- YYYY-MM-DD -->

Quick snapshot of what is running, what is stable, and any known issues.
Update this after significant changes.

## Overall status

<!-- Green / Yellow / Red and a one-liner summary -->

## What is running

| Service | Status | Host | Notes |
|---------|--------|------|-------|
| <!-- service --> | running / stopped / degraded | <!-- host --> | <!-- notes --> |

## Known issues

<!-- List any current problems, degraded services, or work-in-progress states -->

## Last stable configuration

<!-- Describe or link to the last known-good state if something breaks -->

## Recent changes

<!-- Brief log of the last 3-5 changes made — more detail belongs in DECISIONS.md -->
EOF

  # --------------------------------------------------------------------------
  # NEXT_STEPS.md
  # --------------------------------------------------------------------------
  cat > NEXT_STEPS.md << 'EOF'
# Next steps

Planned work, in-progress tasks, and ideas backlog.
Check off items as they are completed. Move finished items to DECISIONS.md.

## In progress

<!-- Tasks actively being worked on -->

## Planned

<!-- Upcoming work with rough priority order -->

## Backlog / ideas

<!-- Lower-priority items or ideas not yet scheduled -->

---

## Deferred tasks from monorepo migration

### 1. Audit and update internal path references in each subfolder

After migration from standalone repos to this monorepo, some scripts and docs
may still reference the old file structure or standalone clone paths.

Known example: the Proxmox post-install script broke previously due to
assumed file paths that no longer matched reality. Each subfolder needs a
pass to:
- Update any hardcoded paths (e.g. ~/chaseworkslab-proxmox -> ~/chaseworkslab/proxmox)
- Update clone URLs if scripts reference the old per-repo GitHub URLs
- Fix any relative path assumptions in shell scripts

Priority: high — do this before relying on any subfolder script in production.

### 2. Add copy-paste quick-start sections to each subfolder README

Each subfolder's README.md should have a prominent "Getting Started" section
near the top with copy-paste install/clone commands — the same way a
well-maintained open-source tool presents its installation instructions.

Users should not need to read raw script code to find the relevant
curl command or install invocation.

Template structure for each subfolder README:

    ## Quick start

    Clone the monorepo (if you haven't already):

        git clone https://github.com/chaserbot/chaseworkslab.git ~/chaseworkslab

    Then run the install/setup script:

        cd ~/chaseworkslab/<subfolder>
        bash <install-script>.sh

Priority: medium — improves usability on new machines.
EOF

  # --------------------------------------------------------------------------
  # DECISIONS.md
  # --------------------------------------------------------------------------
  cat > DECISIONS.md << EOF
# Decisions

Architectural decision log. Add an entry whenever a meaningful infrastructure
or configuration decision is made. Entries are most recent first.

Format:

    ## YYYY-MM-DD: Short title
    **Decision:** What was decided.
    **Why:** Rationale, alternatives considered.
    **Rollback:** How to undo if needed.

---

## $(date +%Y-%m-%d): Consolidate all chaseworkslab repos into a monorepo

**Decision:** Merged 10 standalone GitHub repos into a single monorepo
(`chaserbot/chaseworkslab`) using `git read-tree` to preserve full commit history
per subfolder.

**Why:** Maintaining separate repos meant cloning each one individually on
every new machine. A monorepo allows a single `git clone` to get everything,
makes cross-repo changes atomic, and simplifies context loading for AI tools.

**Repos merged:** chaseworkslab-dotfiles, chaseworkslab-llm, chaseworkslab-docker,
chaseworkslab-ansible, chaseworkslab-proxmox, chaseworkslab-arr,
chaseworkslab-monitoring, chaseworkslab-lxc, chaseworkslab-inventory, homelab-context.

**Rollback:** Each source repo is still intact on GitHub and was not deleted.
To revert to standalone workflow, simply clone the individual repos again.
The monorepo can be abandoned without any data loss.
EOF

  git add README.md AGENTS.md CLAUDE.md STACK.md CURRENT_STATE.md NEXT_STEPS.md DECISIONS.md
  git commit -m "docs: add LLM context and memory files to monorepo root"

  success "Context files written and committed."
  echo ""
}

# ==============================================================================
# Section 5: Optional GitHub push via gh CLI
# ==============================================================================
push_to_github() {
  cd "$MONOREPO_DIR"

  if ! command -v gh &>/dev/null; then
    echo ""
    warn "gh CLI not found. Push manually when ready:"
    echo ""
    echo "  cd $MONOREPO_DIR"
    echo "  git remote add origin https://github.com/${GITHUB_USER}/${MONOREPO_REPO_NAME}.git"
    echo "  git push -u origin main"
    echo ""
    echo "  (Create the repo on GitHub first if it doesn't exist:"
    echo "   https://github.com/new  — name it '${MONOREPO_REPO_NAME}')"
    return 0
  fi

  info "gh CLI found. Creating GitHub repo and pushing..."

  # Check if the repo already exists
  if gh repo view "${GITHUB_USER}/${MONOREPO_REPO_NAME}" &>/dev/null 2>&1; then
    warn "  GitHub repo ${GITHUB_USER}/${MONOREPO_REPO_NAME} already exists — skipping creation."
    # Add remote if not already set
    if ! git remote | grep -q "^origin$"; then
      git remote add origin "https://github.com/${GITHUB_USER}/${MONOREPO_REPO_NAME}.git"
    fi
    git push -u origin main
  else
    gh repo create "${GITHUB_USER}/${MONOREPO_REPO_NAME}" \
      --public \
      --description "$MONOREPO_DESCRIPTION" \
      --source . \
      --remote origin \
      --push
  fi

  success "Pushed to https://github.com/${GITHUB_USER}/${MONOREPO_REPO_NAME}"
}

# ==============================================================================
# Section 6: Verification summary
# ==============================================================================
print_verification() {
  echo ""
  success "All done! Verify your migration:"
  echo ""
  echo "  cd $MONOREPO_DIR"
  echo ""
  echo "  # Confirm all 10 subfolders exist:"
  echo "  ls -1"
  echo ""
  echo "  # Total commit count (should be sum of all source repos + merge commits):"
  echo "  git log --oneline | wc -l"
  echo ""
  echo "  # Confirm history is preserved per subfolder:"
  echo "  git log --oneline -- dotfiles/ | head -5"
  echo "  git log --oneline -- ansible/  | head -5"
  echo "  git log --oneline -- proxmox/  | head -5"
  echo ""
  echo "  # Confirm blame / follow works:"
  echo "  git log --follow -- dotfiles/install.sh | head -10"
  echo ""
}

# ==============================================================================
# Main
# ==============================================================================
echo ""
info "chaseworkslab monorepo consolidation"
info "Target: $MONOREPO_DIR"
echo ""

preflight
init_monorepo

cd "$MONOREPO_DIR"
info "Importing repos..."
echo ""

import_repo "chaseworkslab-dotfiles"   "dotfiles"
import_repo "chaseworkslab-llm"        "llm"
import_repo "chaseworkslab-docker"     "docker"
import_repo "chaseworkslab-ansible"    "ansible"
import_repo "chaseworkslab-proxmox"    "proxmox"
import_repo "chaseworkslab-arr"        "arr"
import_repo "chaseworkslab-monitoring" "monitoring"
import_repo "chaseworkslab-lxc"        "lxc"
import_repo "chaseworkslab-inventory"  "inventory"
import_repo "homelab-context"          "homelab-context"

write_context_files
push_to_github
print_verification
