# Cluster-specific configuration. Set your project/account in local.zsh (see local.zsh.example).

# ==========================
# Any SLURM cluster
# ==========================
if (( $+commands[sbatch] )); then
  # SLURM sacct configuration
  export SACCT_FMT="jobid,state,partition,jobname,reqcpus,reqmem,nodelist,timelimit,submit,start,end,elapsed,account"
  alias sacct="sacct -X --format=\${SACCT_FMT} --units G"
  alias sq='squeue --me --format="%.10i %.12P %.30j %.8T %.10M %.10l %.5D %R"'

  # Disable bytecode writing: avoids lots of small files on parallel filesystems
  export PYTHONDONTWRITEBYTECODE=1
fi

# ==========================
# Jean Zay (IDRIS)
# ==========================
if [[ $HOST == jean-zay* || -d /lustre/fshomisc/sup ]]; then
  export UV_HTTP_TIMEOUT=36000
  : ${JZ_PROJECT:=$IDRPROJ}  # e.g. JZ_PROJECT=abc in local.zsh -> accounts abc@cpu, abc@h100, ...

  # Switch between projects (ex: switch abc)
  switch() {
    [[ -n $1 ]] || { echo "Usage: switch <project>"; return 1 }
    eval "$(idrenv -d $1)" && JZ_PROJECT=$1
  }

  # Environment modules (spack)
  [[ -s /lustre/fshomisc/sup/spack_soft/environment-modules/current/init/zsh ]] \
    && source /lustre/fshomisc/sup/spack_soft/environment-modules/current/init/zsh

  # Default SLURM options for srun
  if [[ -n $JZ_PROJECT ]]; then
    export SLURM_ACCOUNT=$JZ_PROJECT@cpu
  fi
  export SLURM_CPUS_PER_TASK=2
  export SLURM_PARTITION=cpu_p1,prepost,visu,compil,compil_h100
  export SLURM_HINT=nomultithread
  export SLURM_TIMELIMIT=2:00:00

  # Interactive jobs: `cpu [srun args]`, `h100 [n_gpus]`, `a100 [n_gpus]`, `v100 [n_gpus]`
  cpu() { srun --qos=qos_cpu-dev "$@" -D "$PWD" --pty zsh -i }
  _jz_gpu() {
    local gpu=$1 partition=$2 qos=$3 cpus_per_gpu=$4 n=${5:-1}
    srun --gres=gpu:$n --constraint=$gpu --cpus-per-task=$(( n * cpus_per_gpu )) \
      ${JZ_PROJECT:+--account=$JZ_PROJECT@$gpu} --partition=$partition --qos=$qos \
      --time=2:00:00 -D "$PWD" --pty zsh -i
  }
  h100() { _jz_gpu h100 gpu_p6 qos_gpu_h100-dev 24 "$@" }
  a100() { _jz_gpu a100 gpu_p5 qos_gpu_a100-dev 8 "$@" }
  v100() { _jz_gpu v100 gpu_p13 qos_gpu-dev 10 "$@" }

  # VSCode tunnel: file-based token auth and a fixed machine ID to avoid relogging on different nodes
  export VSCODE_CLI_USE_FILE_KEYCHAIN=1
  export VSCODE_CLI_DATA_DIR=~/.vscode-cli
  [[ -s "$HOME/.machine_id" ]] || cat /etc/machine-id > "$HOME/.machine_id"
  alias tunnel="unshare -r -m -u -f sh -c 'mount --bind $HOME/.machine_id /etc/machine-id; hostname hpc-tunnel; code tunnel --name jz --accept-server-license-terms'"

  export SINGULARITY_TMPDIR=~/.singularity/tmp

  # Optional HTTP proxy for compute nodes through the jean-zay1 frontal node
  # (requires running `gost -L http://0.0.0.0:8888 -F $http_proxy` on jean-zay1, and ~/.slurm_env)
  if [[ -f "$HOME/.slurm_env" ]]; then
    export BASH_ENV="$HOME/.slurm_env"
    export SBATCH_EXPORT="ALL,BASH_ENV"
    if [[ -n "$SLURM_JOB_ID" && "$SLURM_JOB_PARTITION" != "prepost" ]]; then
      FRONTAL_IP=$(getent hosts jean-zay1 | awk '{print $1}')
      export HTTP_PROXY="http://${FRONTAL_IP}:8888" HTTPS_PROXY="http://${FRONTAL_IP}:8888"
    fi
  fi
fi

# ==========================
# LUMI (CSC)
# ==========================
if [[ -d /appl/lumi ]]; then
  # LUMI_PROJECT=project_465000000 in local.zsh sets the default SLURM account
  if [[ -n $LUMI_PROJECT ]]; then
    export SLURM_ACCOUNT=$LUMI_PROJECT SBATCH_ACCOUNT=$LUMI_PROJECT SALLOC_ACCOUNT=$LUMI_PROJECT
    # Keep caches out of the small home quota
    export UV_CACHE_DIR=${UV_CACHE_DIR:-/scratch/$LUMI_PROJECT/$USER/.cache/uv}
    export PIP_CACHE_DIR=${PIP_CACHE_DIR:-/scratch/$LUMI_PROJECT/$USER/.cache/pip}
  fi

  # Interactive jobs: `cpu [srun args]`, `gpu [n_gpus]` (dev partitions, 1h)
  cpu() { srun --partition=debug --time=0:30:00 "$@" -D "$PWD" --pty zsh -i }
  gpu() { srun --partition=dev-g --gpus-per-node=${1:-1} --cpus-per-task=$(( 7 * ${1:-1} )) --time=1:00:00 -D "$PWD" --pty zsh -i }
fi
