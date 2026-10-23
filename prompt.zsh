# Prompt: Starship (https://starship.rs) with a per-host background color, plain zsh prompt as fallback.
#
# The host segment color is derived from the hostname so each machine is recognizable at a glance.
# Override it in local.zsh with ZSH_HOST_COLOR=<0-255>. Set ZSH_PROMPT_GIT_STATUS=0 to disable git
# status in the prompt (useful in huge repositories on slow parallel filesystems).

() {
  local host=${HOST%%.*} ch
  local -i hash=5381 color fg
  for ch in ${(s::)host}; do (( hash = (hash * 33 + #ch) % 2147483647 )); done
  color=${ZSH_HOST_COLOR:-$(( hash % 214 + 17 ))}

  # Black or white text depending on the background luminance (xterm 256-color cube)
  if (( color >= 16 && color <= 231 )); then
    local -i i=$(( color - 16 ))
    (( fg = (299 * (i / 36) + 587 * (i / 6 % 6) + 114 * (i % 6)) > 2500 ? 0 : 15 ))
  elif (( color >= 232 )); then
    (( fg = color > 243 ? 0 : 15 ))
  else
    (( fg = color == 0 || color == 1 || color == 4 || color == 5 || color == 8 ? 15 : 0 ))
  fi

  if (( $+commands[starship] )); then
    # Generate the host-specific config from the template (cached; regenerated when the template changes)
    local git_disabled=false
    [[ ${ZSH_PROMPT_GIT_STATUS:-1} == 0 ]] && git_disabled=true
    local template="$ZDOTDIR/starship.toml"
    local config="$ZSH_CACHE_DIR/starship-$color-$git_disabled.toml"
    if [[ ! -s $config || $template -nt $config ]]; then
      local content="$(<$template)"
      content=${content//__HOST_BG__/$color}
      content=${content//__HOST_FG__/$fg}
      content=${content//__GIT_STATUS_DISABLED__/$git_disabled}
      print -r -- "$content" >| "$config"
    fi
    export STARSHIP_CONFIG=$config
    eval "$(starship init zsh)"
  else
    # Fallback: host, directory, git branch, exit status
    autoload -Uz vcs_info
    zstyle ':vcs_info:git:*' formats ' %F{green}%b%f'
    add-zsh-hook precmd vcs_info
    setopt PROMPT_SUBST
    PROMPT="%K{$color}%F{$fg} %m %f%k %F{blue}%~%f\${vcs_info_msg_0_}"$'\n'"%(?.%F{green}.%F{red})❯%f "
    RPROMPT='%(?..%F{red}✘ %?%f)'
  fi
}
