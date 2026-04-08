#!/usr/bin/env bash
# this tool can print available triton-defined themes, or change current theme.

## ======== source =========
triconf="$HOME/.config/triton/triton.conf"
if [[ ! -f "$triconf" ]]; then
  warn "Config file 'triton.conf' missing from '$(get_dirname "${triconf}")'."
else
  source "${triconf}"
fi

## ======== functions ========

# update triton variable $1 with value $2, if it exists
up_trivar() {
  local key="$1"
  local val="$2"
  local tmp_file="${triconf}.tmp"

  if [[ -f "${triconf}" ]]; then
    # Read the file line by line and write to a temp file
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^"${key}=" ]]; then
        printf "%s=%s\n" "$key" "$val"
      else
        printf "%s\n" "$line"
      fi
    done <"${triconf}" >"${tmp_file}"

    # Move the temp file back to the original
    mv "${tmp_file}" "${triconf}"
  else
    error "no file '${triconf}' found; variable '$1' not updated".
  fi
}

# set/clear a themes_array and fill it with names based on directories within dir_themes which contain a triton_theme.conf file
get_themes() {
  themes_array=()
  for dir in "$dir_themes"/*/; do
    local clean_dir="${dir%/}"

    if [[ -f "${clean_dir}/.triton/triton_theme.conf" ]]; then
      if grep -q "#TRITON_THEME" "${clean_dir}/.triton/triton_theme.conf"; then
        themes_array+=("$(get_basename "$clean_dir")")
      fi
    fi
  done
}

list_themes() {
  get_themes
  echo "AVAILABLE THEMES: "
  for theme in "${themes_array[@]}"; do
    echo "- $theme"
  done
}

themename_exists() {
  get_themes
  [[ " ${themes_array[@]} " =~ " $1 " ]]
}

valid_dir() {
  if [[ "$2" = "-o" ]] || [[ "$2" == "--output" ]]; then
    local status='either valid or invalid.'
    if [[ -d "$1" ]]; then
      status='VALID'
    else
      status='INVALID'
    fi
    debug "Directory $1 is $status"
  fi
  [[ -d "$1" ]]
}

# Check for potential stow conflicts with file paths, then ask the user to confirm deletion of each before continuing
# $1 should be the directory to look through
check_stow_conflicts() {
  if [[ ! -d "$1" ]]; then
    error "check_stow_conflicts: input argument not a directory"
  fi
  local search_dir="${1%/}"
  local paths=($(find $search_dir -type f))
  for path in "${paths[@]}"; do
    local dot_mirror="$HOME/${path#$search_dir/}"
    debug "dot_mirror == ${dot_mirror}"
    if [[ -f "${dot_mirror}" ]]; then
      if ask "CONFLICT: Non-symlink file found at: ${dot_mirror}. This must be deleted to set theme to ${switchto}. Delete file?"; then
        rm "${dot_mirror}"
      else
        error "Switching to triton theme ${switchto} would encounter a stow conflict with existing file: ${dot_mirror}"
      fi
    fi
  done
}

# make the current_theme director if it does not exist
write_current_theme_dir() {
  if [[ -d "${dir_triton}" ]]; then
    if [[ -d "${dir_current_theme}" ]]; then
      rm -rf "${dir_current_theme}"
    fi
    mkdir "${dir_current_theme}"
    touch "${dir_current_theme}/.stow"
  else
    error "Required directory ${dir_triton} not found."
  fi
}

write_new_current_theme() {
  if [[ -d "${source_theme_dir}" ]]; then # if source dir for theme we want to switch to exists...
    shopt -s nullglob
    for subdir in "${source_theme_dir}"/*/; do # then for each subdirectory within it...
      local dir_name=$(get_basename "${subdir%/}")
      local dot_mirror="${dir_current_theme}/$dir_name" # manage current_theme dir version
      if [[ -d "$dot_mirror" ]]; then
        ## this should never happen; this provides a failsafe
        # remove the directory if it exists, so that it may be replaced
        rm -rf "$dot_mirror"
      fi
      # copy desired ${switchto} subdirectory to new current_theme directory
      cp -ra "$subdir" "${dot_mirror}"
      debug "RAN: cp -ra $dir_name TO ${dir_current_theme}"
    done
    shopt -u nullglob
  else
    error "could not find expected theme directory: ${source_theme_dir}"
  fi
}

unstow_current_theme() {
  # unstow symlinks related to the theme last generated and set by the user
  if [[ -d "${dir_current_theme}" ]]; then
    shopt -s nullglob
    for subdir in "${dir_current_theme}"/*/; do
      stow -D -t "$HOME" -d "${subdir%/}" .
    done
    shopt -u nullglob
  fi
}

# generate the current_theme files, then stow them into the $HOME directory.
stow_current_theme() {
  # stow symlinks to dir_current_theme/ contents
  if [[ -d "${dir_current_theme}" ]]; then
    # scan directory for potential conflicts
    shopt -s nullglob
    for subdir in "${dir_current_theme}"/*/; do
      check_stow_conflicts "${subdir%/}"
    done
    shopt -u nullglob
    info "No stow conflicts detected."
    # there being no conflicts, stow accordingly
    shopt -s nullglob
    for subdir in "${dir_current_theme}"/*/; do
      stow -t "$HOME" -d "${subdir%/}" .
    done
    shopt -u nullglob
  else
    error "Failed to stow theme: ${switchto}; no current_theme directory generated at expected directory: ${dir_triton}."
  fi
}

set_theme() {
  get_themes
  if ! themename_exists $1; then
    error "Theme \"$1\" does not exist in {dir_themes}."
  else
    local switchto=$1
    # ensure theme dependencies are installed
    source_theme_dir="${dir_themes}/${switchto}"
    source "${source_theme_dir}/.triton/triton_theme.conf"
    for dep in "${theme_dependencies[@]}"; do
      if ! check_command "$dep"; then
        error "Dependency \"$dep\" for theme \"${switchto}\" is not installed."
      fi
    done
    unstow_current_theme
    write_current_theme_dir
    write_new_current_theme
    stow_current_theme
  fi
  up_trivar "current_theme" "${switchto}"
  if [[ -f "${source_theme_dir}/.triton/art.txt" ]]; then
    # output theme art if it exists
    cat "${source_theme_dir}/.triton/art.txt"
  fi
  if [[ -f "${source_theme_dir}/.triton/reload.sh" ]] && grep -q "#TRITON_RELOAD" "${dir_themes}/${switchto}/.triton/reload.sh"; then
    # run theme reload script if it exists
    bash "${source_theme_dir}/.triton/reload.sh"
  else
    warn "no triton \"reload.sh\" script found at \"${source_theme_dir}/.triton\"."
  fi
}

### ========= SCRIPT =========
validate_themetool() {
  # check whether a triton config file exists
  if ! [[ -f "${triconf}" ]]; then
    error "No triton.conf file was found under desired path \"$HOME/.config/triton/\". To create one now, run: triton init"
    exit 1
  fi
  # check whether a dir_themes variable is specified in triton.conf
  if ! valid_dir "${dir_themes}"; then
    if valid_dir "$HOME/.triton/.themes"; then
      warn ".themes directory \"${dir_themes}\" specified in triton.conf DOES NOT EXIST. "
      if ask "A .themes directory was found in expected directory: ${dir_triton}. Would you like to use it?"; then
        dir_themes="$HOME/.triton/.themes"
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
}
