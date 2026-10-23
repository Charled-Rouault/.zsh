# .zsh

A fast, portable zsh config for macOS and HPC clusters (Jean Zay, LUMI, any SLURM machine).
No root needed: plugins are cloned into `~/.zsh/plugins` and CLI tools are installed into `~/.local/bin`.

## Installation

```bash
git clone https://github.com/Charled-Rouault/.zsh.git ~/.zsh
~/.zsh/install.sh   # symlinks ~/.zshrc and ~/.tmux.conf, backs up existing files
exec zsh
```

On the first start, plugins are cloned, and missing tools are downloaded in the background (open a new shell when it's done).
On clusters, do this on a **login node** (compute nodes have no internet); `$HOME` is shared, so compute nodes then use the same tools.

### Font

The prompt uses [Nerd Font](https://www.nerdfonts.com) icons. Install one **on the machine running the terminal** (your laptop), not on the cluster: over SSH, glyphs are drawn locally.

```bash
brew install --cask font-meslo-lg-nerd-font
```

Then select *MesloLGS Nerd Font Mono* in your terminal settings (Terminal.app: Settings → Profiles → Text → Font; VSCode: `"terminal.integrated.fontFamily": "MesloLGS Nerd Font Mono"`).

## Layout

| File | Purpose |
| --- | --- |
| `.zshrc` | Main config: completion, plugins, history, key bindings, aliases |
| `tools.zsh` | Auto-install of standalone CLI tools into `~/.local/bin` |
| `clusters.zsh` | SLURM, Jean Zay and LUMI specific settings |
| `prompt.zsh`, `starship.toml` | Starship prompt with per-host color, plain zsh fallback |
| `.zsh_unplugged` | Minimal plugin manager ([zsh_unplugged](https://github.com/mattmc3/zsh_unplugged)) |
| `local.zsh` | Your machine-specific settings, not versioned (see `local.zsh.example`) |
| `.api_keys` | Sourced if present, not versioned |

## Prompt

[Starship](https://starship.rs), two lines: host, directory and git on the left; exit status, duration, background jobs, Python env and time on the right.

- The host segment color is derived from the hostname, so each machine is recognizable at a glance. Force it with `ZSH_HOST_COLOR=<0-255>` in `local.zsh`.
- Timeouts keep the prompt responsive on Lustre/GPFS. In huge repositories, `ZSH_PROMPT_GIT_STATUS=0` turns off git status.
- Without starship, a plain zsh prompt with the same information is used.

Customize in `starship.toml` (the per-host copy is regenerated in `~/.cache/zsh` automatically).

## Tools

Each tool is optional: its integration is only enabled when it's installed. Missing ones are installed automatically (Homebrew on macOS, static GitHub release binaries elsewhere), at most once a day per host. Disable with `ZSH_TOOLS_AUTO_INSTALL=0`.

- `zsh-install-tools [tool...]`: install missing tools, or (re)install/upgrade the given ones.

| Tool | Usage |
| --- | --- |
| [fzf](https://github.com/junegunn/fzf) | `Ctrl+R` fuzzy history, `Ctrl+T` insert a file, `Alt+C` cd into a directory, fuzzy `Tab` completion ([fzf-tab](https://github.com/Aloxaf/fzf-tab), `<`/`>` to switch groups) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `z foo` jumps to the most frecent directory matching `foo`, `zi` picks interactively (falls back to [zsh-z](https://github.com/agkozak/zsh-z)) |
| [eza](https://github.com/eza-community/eza) | `ls`, `ll` (with git status and icons), `lt` (tree) |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting, colored `man` pages |
| [fd](https://github.com/sharkdp/fd) | fast `find`, used by fzf |
| [direnv](https://direnv.net) | per-directory environment from `.envrc` |
| [starship](https://starship.rs) | prompt |

## Plugins

- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions): ghost-text suggestions from history and completion. Accept with `→` or `End`.
- [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search): type part of a command, then `↑`/`↓` (or `Alt+↑`/`Alt+↓`) to cycle through matching history.
- [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting): command-line syntax highlighting.
- [zsh-completions](https://github.com/zsh-users/zsh-completions): extra completion definitions.

Update all plugins with `plugin-update`. For a clean re-install: `rm -rf ~/.zsh/plugins && exec zsh`.

## Other features

- Python virtual environments in `.venv` are activated/deactivated automatically on `cd`.
- `nvm` is loaded lazily on the first `nvm`/`node`/`npm`/`npx` call.
- `Ctrl+X Ctrl+E` edits the current command in `$EDITOR`.
- Large shared history with timestamps; commands starting with a space are not recorded.

## Clusters

Set your project in `local.zsh` (see `local.zsh.example`).

- **Any SLURM cluster**: `sq` (formatted `squeue --me`), `sacct` with a useful format.
- **Jean Zay** (`JZ_PROJECT`, defaults to `$IDRPROJ`): `switch <project>`, interactive jobs `cpu`, `h100 [n_gpus]`, `a100 [n_gpus]`, `v100 [n_gpus]`, VSCode `tunnel`, environment modules.
- **LUMI** (`LUMI_PROJECT`): default SLURM account, uv/pip caches on `/scratch`, interactive jobs `cpu`, `gpu [n_gpus]`.

If `chsh` is not allowed on a cluster, add `[ -t 1 ] && exec zsh -l` at the end of `~/.bash_profile`.

## Tmux

`.tmux.conf` is symlinked to `~/.tmux.conf`. [TPM](https://github.com/tmux-plugins/tpm) is installed automatically and the status bar shows CPU, RAM, GPU, network and disk usage (press `Ctrl+B` then `I` once to install the plugins).
