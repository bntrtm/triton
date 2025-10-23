#!/bin/bash
source "$(dirname "$0")/helpers.sh"

# creates a config file under the expected directory: $HOME/.config/triton/triton.conf
function write_config_file () {
  triconf="$HOME/.config/triton/triton.conf"
  if ! test -f "${triconf}"; then
    # make directory, create file
    mkdir -p "$HOME/.config/triton" && touch ${triconf}
    default="$(dirname "$0")/default_triton.conf"
    cat ${default} > ${triconf};
    echo "Wrote file: ${triconf}"
    user_dir_dotfiles=""
    #askpath "dotfiles" user_dir_dotfiles
    #sed -i "s@^dir_dotfiles=.*@dir_dotfiles=${user_dir_dotfiles}@" "${triconf}"
  else
    echo "DENIED: ${triconf} already written."
  fi
}
