#!/bin/bash
# this tool can print available triton-defined themes, or change current dotfile theme.

## ======== source =========
triconf="$HOME/.config/triton/triton.conf"
srcs=( "$(dirname "$0")/helpers.sh" "${triconf}")
for element in ${srcs[@]}; do
  if ! test -f "$element"; then
    echo "WARNING: could not source ${element} for \"$0\"."
  else
    source "${element}"
  fi
done

## ======== functions ========

# update triton variable $1 with value $2, if it exists
function up_trivar () {
  if valid_dir "${triconf}"; then
    sed -i "s@^$1=.*@$1=$2@" "${triconf}"
  else
    echo "ERROR: no file \"${triconf}\" found; variable \"$1\" not updated".
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

# Check for potential stow conflicts with file paths, then ask the user to confirm deletion of each before continuing
# $1 should be the directory to look through
function check_stow_conflicts () {
  paths=($(find $1 -type f))
  for path in "${paths[@]}"; do
    local dotmirror="$HOME/${path/$1/}"
    echo "dotmirror == ${dotmirror}"
    if [ -f "${dotmirror}" ]; then
      if ask "CONFLICT: Non-symlink file found at: ${dotmirror}. This must be deleted to set theme to $switchto. Delete file?"; then
        rm "${dotmirror}"
      else
        error "Switching to triton theme ${switchto} would encounter a stow conflict with existing file: ${dotmirror}"
      fi
    fi
  done
}

# Recursively loop through a directory and check for potential stow conflicts
# $1 is the base directory to loop through, $2 is the basename of the original directory
function check_nonsyms () {
  if ! valid_dir "$1"; then
    error "loop_directory: no valid directory \"$1\""
  fi
  dot_mirror="$1/$2"
  local dir="$1"
  # Loop through each item in the directory
  for item in "$dir"/*; do
    # Check if the item is a directory
    if valid_dir "$item"; then
      # If it's a directory, recursively call the function
      check_nonsyms "$item" "$2"
    else
      # If it's a file, ask if an identical file path exists within the $HOME directory
      if test -f "$HOME/${dotmir}/$(basename "$item")"; then
        if ask "ATTENTION: Non-symlink file found at: $HOME/${dotmir}/$(basename "$item"). This must be deleted to set theme to $switchto. Delete file?"; then
          rm "$HOME/${dotmir}/$(basename "$item")"
        fi
      fi
    fi
  done
}

function write_new_current_theme () {
  if valid_dir "${dir_themes}/$switchto"; then
    for dir in "${dir_themes}/$switchto"/*/; do
      local dotmir="${dir_current_theme}/$(basename "$dir")"
      if valid_dir "$dotmir"; then
        ## this should never happen; this provides a failsafe
        # remove the directory if it exists, so that it may be replaced
        rm -r "$dotmir"
        # replace the directory
        cp -ra "$dir" "${dir_current_theme}"
      else
        # copy desired $switchto subdirectory to new current_theme directory
        cp -ra "$dir" "${dir_current_theme}"
        echo "cp -ra $dir TO ${dir_current_theme}"
      fi
    done
  fi
}

function unstow_current_theme () {
# stow symlinks to current_theme contents in the dir_dotfiles directory
  if [ -d "${dir_current_theme}" ]; then
    for dir in "${dir_current_theme}"/*/; do
      stow -D -t "$HOME" -d "${dir_current_theme}" "$(basename "$dir")/"
    done
  fi
}

# generate the current_theme files, then stow them into the $HOME directory.
function write_current_theme_dir () {
  if [ -d "${dir_triton}" ]; then
    if [ -d "${dir_current_theme}" ]; then
      rm -rf "${dir_current_theme}"
    fi
    mkdir "${dir_triton}/current_theme"
    touch "${dir_triton}/current_theme/.stow"
  else
    error "Required directory ${dir_triton} not found."
  fi
}

function stow_current_theme () {
# stow symlinks to dir_current_theme/ contents
  if [ -d "${dir_current_theme}" ]; then
    # scan directory for potential conflicts
    for dir in "${dir_current_theme}"/*/; do
      check_stow_conflicts "$dir"
    done
    echo "No stow conflicts detected."
    # there being no conflicts, stow accordingly
    for dir in "${dir_current_theme}"/*/; do
      stow -t "$HOME" -d "${dir_current_theme}" "$(basename "$dir")/"
    done
  else
    error "Failed to stow theme: ${switchto}; no current_theme directory generated at expected directory: ${dir_triton}."
  fi
}

function set_theme () {
  get_themes
  if ! themename_exists $1; then
    error "Theme \"$1\" does not exist in {dir_themes}."
  else
    switchto=$1
  # ensure theme dependencies are installed
  source "${dir_themes}/${switchto}/.triton/triton_theme.conf"
  for dep in "${theme_dependencies[@]}"; do
    if ! check_command "$dep"; then
      error "Dependency \"$dep\" for theme \"$switchto\" is not installed."
    fi
  done
    unstow_current_theme
    write_current_theme_dir
    write_new_current_theme
    stow_current_theme
  fi
  sed -i "s/^current_theme=.*/current_theme=\"$switchto\"/" "${triconf}"
  if test -f "${dir_themes}/$switchto/.triton/art.txt"; then
    #clear
    cat "${dir_themes}/$switchto/.triton/art.txt"
  fi
  if [ -f "${dir_themes}/${switchto}/.triton/reload.sh" ] && grep -q "#TRITON_RELOAD" "${dir_themes}/${switchto}/.triton/reload.sh"; then
    bash "${dir_themes}/${switchto}/.triton/reload.sh"
  else
    echo "NOTICE: no triton \"reload.sh\" script found at \"${dir_themes}/{switchto}/.triton\"."
  fi
}

### ========= SCRIPT =========

## ======== check expectations =========
# check whether a triton config file exists
if ! test -f "${triconf}"; then
  echo "ERROR: No triton.conf file was found under desired path \"$HOME/.config/triton/\"."
  echo "       To create one now, run: triton init"
  exit 1
fi
# check whether a dir_themes variable is specified in triton.conf
if ! valid_dir "${dir_themes}"; then
  if valid_dir "${dir_dotfiles}/.triton/.themes"; then
    echo "NOTICE: .themes directory \"$dir_themes\" specified in triton.conf DOES NOT EXIST. "
    if ask "A .themes directory was found in expected directory: ${dir_triton}. Would you like to use it?"; then
      dir_themes="${dir_dotfiles}/.triton/.themes"
      up_trivar "dir_themes" "${dir_themes}"
    else
      error "Themes directory \"$dir_themes\" specified in triton.conf DOES NOT EXIST."
      exit 1
    fi
  else
    error "Themes directory \"$dir_themes\" specified in triton.conf DOES NOT EXIST."
    exit 1
  fi
fi
# ensure GNU-Stow is installed
if ! check_command "stow" "GNU-Stow"; then
  error "$0 could not initialize; GNU-Stow is required for triton to run."
fi

