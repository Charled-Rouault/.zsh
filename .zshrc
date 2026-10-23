#!/bin/zsh
# Portable zsh config for macOS and HPC clusters (Jean Zay, LUMI, ...).
# See README.md for installation.

# Zsh config directory (same location as this file, resolving the ~/.zshrc symlink)
ZDOTDIR="${${(%):-%N}:A:h}"
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

# User binaries first: tools auto-installed by tools.zsh land here
export PATH="$HOME/.local/bin:$PATH"
typeset -U path fpath  # deduplicate PATH/fpath entries

# Homebrew (macOS) so its tools are found even in non-login shells
if [[ -z "$HOMEBREW_PREFIX" ]]; then
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x $_brew ]] && eval "$($_brew shellenv)" && break
  done
  unset _brew
fi

# Machine-specific settings (not versioned), loaded early so they can set variables used below
[[ -f "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"

# Auto-install missing CLI tools (starship, fzf, zoxide, eza, bat, fd, direnv) into ~/.local/bin
source "$ZDOTDIR/tools.zsh"

# Environment modules on clusters: zsh does not read /etc/profile.d, so init Lmod/modules if needed
if (( ! $+functions[module] )); then
  for _modinit in /usr/share/lmod/lmod/init/zsh /usr/share/Modules/init/zsh; do
    [[ -r $_modinit ]] && source $_modinit && break
  done
  unset _modinit
fi

# ==========================
# Completion
# ==========================

# Plugin directory and loader (https://github.com/mattmc3/zsh_unplugged)
ZPLUGINDIR="$ZDOTDIR/plugins"
source "$ZDOTDIR/.zsh_unplugged"

# Extra completion definitions must be on fpath before compinit
plugin-load zsh-users/zsh-completions

autoload -Uz compinit
# Only rebuild the completion dump once a day (speeds up startup, especially on Lustre/GPFS)
_stale_dump=($ZSH_CACHE_DIR/zcompdump(N.mh+24))
if (( $#_stale_dump )) || [[ ! -s $ZSH_CACHE_DIR/zcompdump ]]; then
  compinit -i -d "$ZSH_CACHE_DIR/zcompdump"
else
  compinit -C -d "$ZSH_CACHE_DIR/zcompdump"
fi
unset _stale_dump

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'  # case-insensitive, fuzzy-ish
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no  # let fzf-tab handle the menu
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/zcompcache"
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false

# ==========================
# Plugins
# ==========================

repos=(
  "zsh-users/zsh-history-substring-search"
  "zsh-users/zsh-autosuggestions"
  "zdharma-continuum/fast-syntax-highlighting"  # keep last
)
# fzf-tab replaces the completion menu with fzf; must load after compinit, before autosuggestions
(( $+commands[fzf] )) && repos=("Aloxaf/fzf-tab" $repos)
# Fallback directory jumping when zoxide is unavailable
(( $+commands[zoxide] )) || repos+=("agkozak/zsh-z")
plugin-load $repos

zstyle ':fzf-tab:*' switch-group '<' '>'
(( $+commands[eza] )) && zstyle ':fzf-tab:complete:(cd|z|__zoxide_z):*' fzf-preview 'eza -1 --color=always --icons $realpath'

export HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ==========================
# History & options
# ==========================

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY       # save timestamps
setopt SHARE_HISTORY          # share history across sessions (implies incremental append)
setopt HIST_IGNORE_DUPS       # don't record consecutive duplicates
setopt HIST_IGNORE_SPACE      # commands starting with a space are not recorded
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY            # show !! expansions before running them
setopt AUTO_CD                # type a directory name to cd into it
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt INTERACTIVE_COMMENTS   # allow # comments in the interactive shell
setopt NO_BEEP

# Set WORDCHARS to exclude "/"
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>|`@'

# ==========================
# Key bindings
# ==========================

bindkey -e
# History substring search: type a prefix then Up/Down (or Alt+Up/Down)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down
bindkey '^[[1;3A' history-substring-search-up    # Alt+Up
bindkey '^[[1;3B' history-substring-search-down  # Alt+Down

# Word navigation / deletion (Linux terminals, VSCode, and macOS Terminal/iTerm2 Option+arrows)
bindkey '^H' backward-kill-word       # Ctrl+Backspace
bindkey '^[[3;5~' kill-word           # Ctrl+Delete
bindkey '^[[1;3C' forward-word        # Alt+Right
bindkey '^[[1;3D' backward-word       # Alt+Left
bindkey '^[[1;5C' forward-word        # Ctrl+Right
bindkey '^[[1;5D' backward-word       # Ctrl+Left
bindkey '^[f' forward-word            # Option+Right (macOS Terminal)
bindkey '^[b' backward-word           # Option+Left (macOS Terminal)
bindkey '^[[H' beginning-of-line      # Home
bindkey '^[[F' end-of-line            # End
bindkey '^[[3~' delete-char           # Delete

# Edit the current command in $EDITOR with Ctrl+X Ctrl+E
autoload -Uz edit-command-line && zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ==========================
# Modern CLI tools (each only if installed)
# ==========================

# fzf: Ctrl+R history search, Ctrl+T file search, Alt+C cd into a directory
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
  (( $+commands[fd] )) && export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git' \
    FZF_CTRL_T_COMMAND='fd --type f --hidden --exclude .git' \
    FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  export FZF_DEFAULT_OPTS='--height 40% --layout reverse --border'
fi

# zoxide: `z foo` jumps to the most frecent directory matching foo, `zi` picks interactively
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# direnv: per-directory environment from .envrc
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

# eza: modern ls with git status and icons
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first'
  alias ll='eza -laFh --git --icons --group-directories-first'
  alias lt='eza --tree --level 2 --icons'
else
  alias ll='ls -laFh --color=auto'
fi

# bat: syntax-highlighted cat and man pages
if (( $+commands[bat] )); then
  alias cat='bat --paging=never --style=plain'
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT='-c'
fi

# ==========================
# Aliases & functions
# ==========================

alias t=tmux
alias ta="tmux attach"
alias tl="tmux ls"
alias tcap="tmux capture-pane -p"
alias tcapS="tmux capture-pane -pS -1000"
alias c=clear
alias sm="squeue --me"
alias wsync="wandb sync --sync-all"
alias rclone-ui="rclone rcd --rc-web-gui"
alias a=aichat
alias ae="aichat -e"

# Robust sshfs mount: mount-robust host:/path ~/mnt/dir (define your own aliases in local.zsh)
mount-robust() {
  mkdir -p "$2"
  sshfs -o follow_symlinks,reconnect,delay_connect,ServerAliveInterval=5,ServerAliveCountMax=1,ConnectTimeout=5,ConnectionAttempts=1 "$@"
  echo "Mounted $1 -> $2"
}

# Git: set global gitignore if not already set and if ~/.gitignore exists
[[ -f ~/.gitignore && -z "$(git config --global core.excludesfile)" ]] && git config --global core.excludesfile ~/.gitignore

# Source API keys if available (not versioned)
[[ -f "$ZDOTDIR/.api_keys" ]] && source "$ZDOTDIR/.api_keys"

# Auto-activate/deactivate Python virtual environments on directory change
# Uses chpwd hook which triggers on ANY directory change (cd, z, pushd, popd, etc.)
_auto_venv() {
  # First, handle deactivation if we've left the current venv's directory
  if [[ -n "$VIRTUAL_ENV" && -n "$VENV_PROJECT_DIR" ]]; then
    if [[ "$PWD"/ != "$VENV_PROJECT_DIR"/* ]]; then
      echo "🔌 Deactivating virtual environment from $VIRTUAL_ENV"
      type deactivate >/dev/null 2>&1 && deactivate || unset VIRTUAL_ENV
      unset VENV_PROJECT_DIR
    fi
  fi

  # Then, activate a new venv if present and not already active
  if [[ -z "$VIRTUAL_ENV" && -f .venv/bin/activate ]]; then
    echo "📦 Activating virtual environment in $PWD/.venv"
    export VENV_PROJECT_DIR="$PWD"
    source .venv/bin/activate
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_venv
_auto_venv

# nvm is slow to source: load it lazily on first use of nvm/node/npm/npx
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  _nvm_lazy() {
    unset -f nvm node npm npx _nvm_lazy
    source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
  }
  for _cmd in nvm node npm npx; do
    eval "$_cmd() { _nvm_lazy; $_cmd \"\$@\" }"
  done
  unset _cmd
fi

# MLFlow: disable background jobs (introduced in recent versions, default: true)
export MLFLOW_SERVER_ENABLE_JOB_EXECUTION=false

# Cluster-specific configuration (Jean Zay, LUMI)
source "$ZDOTDIR/clusters.zsh"

# ==========================
# Prompt
# ==========================

source "$ZDOTDIR/prompt.zsh"
