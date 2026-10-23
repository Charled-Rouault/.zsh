# Auto-install of standalone CLI tools into ~/.local/bin (no root needed, works on HPC login nodes).
#
# Missing tools are installed in the background at most once a day per host; open a new shell
# afterwards to use them. Run `zsh-install-tools [tool...]` to (re)install manually, e.g. to upgrade.
# Disable with `ZSH_TOOLS_AUTO_INSTALL=0` in local.zsh.

ZSH_TOOLS=(starship fzf zoxide eza bat fd direnv)

# GitHub repo and release asset name of each tool. Placeholders:
#   %v tag (v1.2.3), %V version (1.2.3), %T rust triple, %G go os_arch, %D os-arch
typeset -gA _zt_repo=(
  starship starship/starship  fzf junegunn/fzf  zoxide ajeetdsouza/zoxide  eza eza-community/eza
  bat sharkdp/bat  fd sharkdp/fd  direnv direnv/direnv
)
typeset -gA _zt_asset=(
  starship 'starship-%T.tar.gz'  fzf 'fzf-%V-%G.tar.gz'  zoxide 'zoxide-%V-%T.tar.gz'
  eza 'eza_%T.tar.gz'  bat 'bat-%v-%T.tar.gz'  fd 'fd-%v-%T.tar.gz'  direnv 'direnv.%D'
)

_zt_install_one() {
  emulate -L zsh
  local tool=$1 repo=$_zt_repo[$1] bindir="$HOME/.local/bin"
  [[ -n $repo ]] || { print -u2 "zsh-install-tools: unknown tool '$tool'"; return 1 }

  local os=${(L)$(uname -s)} arch=$(uname -m) triple goarch
  case $arch in
    x86_64|amd64) arch=x86_64; goarch=amd64 ;;
    aarch64|arm64) arch=aarch64; goarch=arm64 ;;
    *) print -u2 "zsh-install-tools: unsupported architecture $arch"; return 1 ;;
  esac
  case $os in
    linux) triple=$arch-unknown-linux-musl ;;
    darwin) triple=$arch-apple-darwin ;;
    *) print -u2 "zsh-install-tools: unsupported OS $os"; return 1 ;;
  esac

  # Resolve the latest tag by following the releases/latest redirect (no API rate limit)
  local url tag
  url=$(curl -fsSLI --connect-timeout 5 -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest") || return 1
  [[ $url == */releases/tag/* ]] || { print -u2 "zsh-install-tools: no release found for $repo"; return 1 }
  tag=${url:t}

  local asset=$_zt_asset[$tool]
  asset=${asset//\%v/$tag}
  asset=${asset//\%V/${tag#v}}
  asset=${asset//\%T/$triple}
  asset=${asset//\%G/${os}_$goarch}
  asset=${asset//\%D/$os-$goarch}

  local tmp=$(mktemp -d) bin
  {
    curl -fsSL --connect-timeout 5 -o "$tmp/$asset" "https://github.com/$repo/releases/download/$tag/$asset" \
      || { print -u2 "zsh-install-tools: $tool: no build $asset"; return 1 }
    if [[ $asset == *.tar.gz ]]; then
      tar -xzf "$tmp/$asset" -C "$tmp" || return 1
      bin=($tmp/**/$tool(N.))
      bin=$bin[1]
    else
      bin=$tmp/$asset
    fi
    [[ -n $bin && -f $bin ]] || { print -u2 "zsh-install-tools: $tool binary not found in $asset"; return 1 }
    mkdir -p "$bindir"
    chmod +x "$bin" && mv -f "$bin" "$bindir/$tool" && print "zsh-install-tools: installed $tool $tag -> $bindir/$tool"
  } always {
    rm -rf "$tmp"
  }
}

# Install the given tools (default: all missing ones). Uses Homebrew on macOS when available.
zsh-install-tools() {
  local t; local -a tools=($@)
  if (( ! $# )); then
    for t in $ZSH_TOOLS; do (( $+commands[$t] )) || tools+=$t; done
  fi
  (( $#tools )) || { print "zsh-install-tools: all tools already installed"; return 0 }
  if [[ $OSTYPE == darwin* ]] && (( $+commands[brew] )); then
    brew install --quiet $tools
  else
    local rc=0; for t in $tools; do _zt_install_one $t || rc=1; done
    return $rc
  fi
}

# Background auto-install of missing tools, at most once a day per host
if [[ ${ZSH_TOOLS_AUTO_INSTALL:-1} == 1 && -o interactive ]] && (( $+commands[curl] )); then
  () {
    local t; local -a missing=()
    for t in $ZSH_TOOLS; do (( $+commands[$t] )) || missing+=$t; done
    (( $#missing )) || return
    local stamp="$ZSH_CACHE_DIR/tools-install-${HOST%%.*}"
    local -a recent=($stamp(N.mh-24))
    (( $#recent )) && return
    touch "$stamp"
    print -P "%F{yellow}zsh: installing missing tools in the background ($missing); open a new shell when done.%f"
    print -P "%F{yellow}     Log: $ZSH_CACHE_DIR/tools-install.log%f"
    zsh-install-tools $missing >>"$ZSH_CACHE_DIR/tools-install.log" 2>&1 &!
  }
fi
