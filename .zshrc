#!/bin/zsh
# TODO: switch to https://github.com/starship/starship

# Zsh config directory (same location as this file)
ZDOTDIR="${${(%):-%N}:A:h}"

# Plugin directory
[[ ! -d "${ZDOTDIR}/plugins" ]] && mkdir -p "${ZDOTDIR}/plugins"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${ZDOTDIR}/plugins/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "${ZDOTDIR}/plugins/powerlevel10k/powerlevel10k.zsh-theme"
fi

# Source zsh_unplugged
source "${ZDOTDIR}/.zsh_unplugged"

# Plugins list
repos=(
  "romkatv/powerlevel10k"
  # "axieax/zsh-starship"
  "zdharma-continuum/fast-syntax-highlighting"
  "zsh-users/zsh-history-substring-search"
  "zsh-users/zsh-autosuggestions"
  "agkozak/zsh-z" # 'z' directory jumping
)

# Load plugins
plugin-load $repos

# zsh-history-substring-search configuration
export HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

# History configuration
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# Add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Git configuration: set global gitignore if not already set and if ~/.gitignore exists
[ -z "$(git config --global core.excludesfile)" ] && [ -f ~/.gitignore ] && git config --global core.excludesfile ~/.gitignore

# Source API keys if available
[[ -f "$ZDOTDIR/.api_keys" ]] && source "$ZDOTDIR/.api_keys"

# Set WORDCHARS to exclude "/"
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>|`@'

# Bind keys for history substring search
bindkey "^[[1;3A" history-substring-search-up # Alt+Up
bindkey "^[[1;3B" history-substring-search-down # Alt+Down

# Key bindings
bindkey '^H' backward-kill-word # Ctrl+Backspace
bindkey '^[[3;5~' kill-word # Ctrl+Delete
bindkey '^[[1;3C' forward-word # Ctrl+Right
bindkey '^[[1;3D' backward-word # Ctrl+Left
bindkey '^[[1;5C' forward-word # Ctrl+Right
bindkey '^[[1;5D' backward-word # Ctrl+Left

# Custom aliases
alias t=tmux
alias ta="tmux attach"
alias tl="tmux ls"
alias sm="squeue --me"
alias wsync="wandb sync --sync-all"
alias ll="ls -laFh --color=auto"
alias c=clear
alias rclone-ui="rclone rcd --rc-web-gui"
alias a=aichat
alias ae="aichat -e"
alias tcap="tmux capture-pane -p"
alias tcapS="tmux capture-pane -pS -1000"

# Mounts for local machine
mount-robust() {
  mkdir -p "$2"
  sshfs -o follow_symlinks,reconnect,delay_connect,ServerAliveInterval=5,ServerAliveCountMax=1,ConnectTimeout=5,ConnectionAttempts=1 "$@"
  echo "Mounted $1 -> $2"
}
alias mount-unicog="mount-robust unicog:/data/ljalouzot ~/mnt/unicog"
alias mount-jz="mount-robust jz:/linkhome/rech/genscp01/uml34gj ~/mnt/jz"
alias mount-coml="mount-robust oberon:/scratch2/ljalouzot ~/mnt/coml"
alias mount-nautilus="mount-robust nautilus:/neurospin/tmp/ljalouzot ~/mnt/nautilus"

# JZ specific config
if [[ "$(whoami)" == "uml34gj" ]]; then
  export UV_HTTP_TIMEOUT=36000

  # Switch between projects (ex switch ioj)
  switch() {
    if [ -z "$1" ]; then
      echo "Usage: switch <environment_name>"
      return 1
    fi
    eval $(idrenv -d $1)
  }

  # Disable Bytecode Writing to force Python to run strictly in memory (faster startup)
  export PYTHONDONTWRITEBYTECODE=1

  # Source environment modules
  export ENV_MODULES=/lustre/fshomisc/sup/spack_soft/environment-modules/current/init/zsh
  [[ -s $ENV_MODULES ]] && source $ENV_MODULES
  # Old:
  # [[ -s "/usr/share/Modules/init/zsh" ]] && source /usr/share/Modules/init/zsh

  # Set default SLURM default options
  # export SBATCH_ACCOUNT=ioj@cpu
  export SLURM_ACCOUNT=ioj@cpu
  # export SBATCH_CPUS_PER_TASK=2
  export SLURM_CPUS_PER_TASK=2
  # export SBATCH_PARTITION=cpu_p1,prepost,visu,compil,compil_h100
  export SLURM_PARTITION=cpu_p1,prepost,visu,compil,compil_h100
  # export SBATCH_HINT=nomultithread
  export SLURM_HINT=nomultithread
  # export SBATCH_TIMELIMIT=2:00:00
  export SLURM_TIMELIMIT=2:00:00

  # SLURM sacct configuration
  export FMT="jobid,state,partition,jobname,reqcpus,reqmem,nodelist,timelimit,submit,start,end,elapsed,account"
  alias sacct="sacct -X --format=${FMT} --units G"

  # Aliases for running interactive jobs
  function cpu() {
    srun --qos=qos_cpu-dev "$@" -D "$(pwd)" --pty zsh -i
  }
  alias v100="srun --gres=gpu:1 --constraint=v100 --cpus-per-task=10 --account=emi@v100 --partition=gpu_p13 --qos=qos_gpu-dev --time=2:00:00 -D $(pwd) --pty zsh -i"
  alias a100="srun --gres=gpu:1 --constraint=a100 --cpus-per-task=8 --account=emi@a100 --partition=gpu_p5 --qos=qos_gpu_a100-dev --time=2:00:00 -D $(pwd) --pty zsh -i"
  alias h100="srun --gres=gpu:1 --constraint=h100 --cpus-per-task=24 --account=ioj@h100 --partition=gpu_p6 --qos=qos_gpu_h100-dev --time=2:00:00 -D \$(pwd) --pty zsh -i"
  alias 2h100="srun --gres=gpu:2 --constraint=h100 --cpus-per-task=48 --account=ioj@h100 --partition=gpu_p6 --qos=qos_gpu_h100-dev --time=2:00:00 -D \$(pwd) --pty zsh -i"
  alias 3h100="srun --gres=gpu:3 --constraint=h100 --cpus-per-task=72 --account=ioj@h100 --partition=gpu_p6 --qos=qos_gpu_h100-dev --time=2:00:00 -D \$(pwd) --pty zsh -i"
  alias 4h100="srun --gres=gpu:4 --constraint=h100 --cpus-per-task=96 --account=ioj@h100 --partition=gpu_p6 --qos=qos_gpu_h100-dev --time=2:00:00 -D \$(pwd) --pty zsh -i"

  # VSCode tunnel settings
  # Enable token file authentification for consistency across nodes
  export VSCODE_CLI_USE_FILE_KEYCHAIN=1
  export VSCODE_CLI_DATA_DIR=~/.vscode-cli
  # Export one machine ID if file does not exist
  [[ -s "$HOME/.machine_id" ]] || cat /etc/machine-id > $HOME/.machine_id
  # Alias to launch VSCode tunnel with fixed machine ID to avoid relogging on different HPC nodes
  alias tunnel="unshare -r -m -u -f sh -c 'mount --bind $HOME/.machine_id /etc/machine-id; hostname hpc-tunnel; code tunnel --name jz --accept-server-license-terms'"

  export SINGULARITY_TMPDIR=~/.singularity/tmp

  # Proxy for MLFlow logging on compute nodes (need running `gost -L http://0.0.0.0:8888 -F $http_proxy` on `jean-zay1`)
  export BASH_ENV="$HOME/.slurm_env"
  export SBATCH_EXPORT="ALL,BASH_ENV"

  if [ -n "$SLURM_JOB_ID" ] && [ "$SLURM_JOB_PARTITION" != "prepost" ]; then
    FRONTAL_IP=$(getent hosts jean-zay1 | awk '{print $1}')
    export HTTP_PROXY="http://${FRONTAL_IP}:8888"
    export HTTPS_PROXY="http://${FRONTAL_IP}:8888"
  fi
fi

# Auto-activate/deactivate Python virtual environments on directory change
# Uses chpwd hook which triggers on ANY directory change (cd, z, pushd, popd, etc.)
function _auto_venv() {
  # First, handle deactivation if we've left the current venv's directory
  if [[ -n "$VIRTUAL_ENV" ]]; then
    local parentdir="$(dirname "$VIRTUAL_ENV")"
    if [[ "$PWD"/ != "$parentdir"/* ]]; then
      echo "🔌 Deactivating virtual environment from $VIRTUAL_ENV"
      deactivate
    fi
  fi

  # Then, activate a new venv if present and not already active
  if [[ -z "$VIRTUAL_ENV" && -d ./.venv ]]; then
    echo "📦 Activating virtual environment in $(pwd)/.venv"
    . .venv/bin/activate
  fi
}

# Register the hook (chpwd is called whenever the current directory changes)
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_venv

# Check for virtual environment at login
_auto_venv

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f $ZDOTDIR/.p10k.zsh ]] || source $ZDOTDIR/.p10k.zsh

# MLFlow: disable background jobs (introduced in recent versions, default: true)
export MLFLOW_SERVER_ENABLE_JOB_EXECUTION=false