#!/bin/sh
# Install this zsh config: symlink ~/.zshrc and ~/.tmux.conf (existing files are backed up).
# Usage: git clone https://github.com/Charled-Rouault/.zsh.git ~/.zsh && ~/.zsh/install.sh
set -e
dir=$(cd "$(dirname "$0")" && pwd)

link() {
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    mv "$2" "$2.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backed up $2"
  fi
  ln -sfn "$1" "$2"
  echo "Linked $2 -> $1"
}

link "$dir/.zshrc" "$HOME/.zshrc"
link "$dir/.tmux.conf" "$HOME/.tmux.conf"
[ -f "$dir/local.zsh" ] || cp "$dir/local.zsh.example" "$dir/local.zsh"

if [ "${SHELL##*/}" != zsh ]; then
  echo "Your login shell is $SHELL. Switch to zsh with: chsh -s \"\$(command -v zsh)\""
  echo "(on clusters where chsh is not allowed, add '[ -t 1 ] && exec zsh -l' at the end of ~/.bash_profile)"
fi
echo "Done. Open a new terminal (first start clones plugins and installs missing tools in the background)."
