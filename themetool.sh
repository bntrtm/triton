#!/bin/bash
# this tool can print available themes, or change current dotfile theme.

## ======== source =========
source ./triton.conf


## ======== functions ========

# read user yes-or-no input
function ask () {
  read -p "$1 (Y/n): " response
  [ -z "$response" ] || [ "$response" = "y" ]
}

# update triton variable $1 with value $2, if it exists
function up_trivar () {
  if valid_dir "./triton.conf"; then
    sed -i "s/^$1=.*/$1=$2/" "./triton.conf"
  else
    echo "ERROR: no file \"triton.conf\" found in $(pwd); variable \"$1\" not updated".
  fi
}

# set/clear a themes_array and fill it with names based on directories within dir_themes which contain a triton_theme.conf file
function get_themes () {
  themes_array=()
  for dir in "$dir_themes"/*/; do
    if test -f "${dir}/.triton/triton_theme.conf"; then
      if grep -q "#TRITON_THEME" "${dir}/.triton/triton_theme.conf"; then
        themes_array+=("$(basename "$dir")")
      fi
    fi
  done
}

function list_themes () {
  get_themes
  echo "AVAILABLE THEMES: "
  echo  ${themes_array[@]} | tr ' ' '\n' | sed 's/^/- /'
}

function themename_exists () {
  get_themes
  [[ " ${themes_array[@]} " =~  " $1 " ]]
}

function valid_dir () {
  if [ "$2" = "-o" ] || [ "$2" == "--output" ]; then
    echo -n "Directory $1 is "
    if [ -d "$1" ]; then
      echo "VALID."
    else
      echo "INVALID."
    fi
  fi
  [ -d "$1" ]
}

function writeconfs () {
  if valid_dir "${dir_themes}/$switchto"; then
    for dir in "${dir_themes}/$switchto"/*/; do
      local dotmir="${dir_current_theme}/$(basename "$dir")"
      if valid_dir "$dotmir"; then
        rm -r "$dotmir"
        echo -e "rm -r $dotmir\n"
        cp -ra "$dir" "${dir_current_theme}"
        echo -e "cp -ra $dir TO ${dir_current_theme}\n"
      else
        cp -ra "$dir" "${dir_current_theme}"
        echo "cp -ra $dir TO ${dir_current_theme}"
      fi
    done
  fi
}

function unstowconfs () {
# stow symlinks to current_theme contents in the dir_dotfiles directory
  if [ -d "${dir_triton}/current_theme" ]; then
    for dir in "${dir_triton}/current_theme"/*/; do
      stow -D -t "$HOME" -d "${dir_triton}/current_theme" "$(basename "$dir")/"
    done
  fi
}

function delconfs () {
  if themename_exists "$current_theme"; then
    if valid_dir "${dir_themes}/$current_theme"; then
      for dir in "${dir_themes}/$current_theme"/*/; do
        local dotmir="${dir_current_theme}/$(basename "$dir")"
        if valid_dir "$dotmir"; then
          rm -r "$dotmir"
          echo -e "rm -r $dotmir\n"
        fi
      done
    fi
  fi
}

function set_theme () {
  get_themes
  if themename_exists $1; then
    switchto=$1
    unstowconfs
    write_current_theme_dir
    writeconfs
    stowconfs
  fi
  sed -i "s/^current_theme=.*/current_theme=\"$switchto\"/" "./triton.conf"
  if test -f "${dir_themes}/$switchto/.triton/art.txt"; then
    #clear
    cat "${dir_themes}/$switchto/.triton/art.txt"
  fi
  hyprctl reload
  killall waybar
  waybar & disown
  killall hyprpaper
  hypaper & disown
}

# generate the current_theme files, then stow them into the $HOME directory.
function write_current_theme_dir () {
  if [ -d "${dir_triton}" ]; then
    if [ -d "${dir_triton}/current_theme" ]; then
      rm -rf "${dir_triton}/current_theme"
    fi
    mkdir "${dir_triton}/current_theme"
  fi
}

function stowconfs () {
# stow symlinks to current_theme contents in the dir_dotfiles directory
  if [ -d "${dir_triton}/current_theme" ]; then
    for dir in "${dir_triton}/current_theme"/*/; do
      stow -t "$HOME" -d "${dir_triton}/current_theme" "$(basename "$dir")/"
    done
  fi
}

### ========= SCRIPT =========

## ======== check expectations =========

# check whether a dir_themes variable is specified in triton.conf
if ! valid_dir "$dir_themes"; then
  if valid_dir "${dir_dotfiles}/.triton/.themes"; then
    echo "NOTICE: .themes directory \"$dir_themes\" specified in triton.conf DOES NOT EXIST. "
    if ask "A .themes directory was found in ${dir_dotfiles}. Would you like to use it?"; then
      dir_themes="${dir_dotfiles}/.themes"
    else
      echo "ERROR: themes directory \"$dir_themes\" specified in triton.conf DOES NOT EXIST."
      exit 1
    fi
  else
    echo "ERROR: themes directory \"$dir_themes\" specified in triton.conf DOES NOT EXIST."
    exit 1
  fi
fi
# ensure GNU-Stow is installed
if ! command -v stow &> /dev/null; then
  echo "ERROR: GNU-Stow is not installed."
  exit 1
fi
