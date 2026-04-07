#!/usr/bin/env bash

# creates a config file under the expected directory: $HOME/.config/triton/triton.conf
write_config_file() {
  local triconf="$HOME/.config/triton/triton.conf"
  if [[ ! -f "${triconf}" ]]; then
    # make directory, create file
    mkdir -p "$HOME/.config/triton" && touch ${triconf}
    default="$(get_dirname "$0")/default_triton.conf"
    cat ${default} >${triconf}
    echo "Wrote file: ${triconf}"
    user_dir_dotfiles=""
    #askpath "dotfiles" user_dir_dotfiles
    #sed -i "s@^dir_dotfiles=.*@dir_dotfiles=${user_dir_dotfiles}@" "${triconf}"
  else
    echo "DENIED: ${triconf} already written."
  fi
}
