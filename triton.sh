#!/bin/bash
# Triton is a program used to easily do...pretty much anything I want.

# =========== SOURCE ===========

source ./themetool.sh

# =========== FUNCTIONS ============

function error () {
  echo -n "ERROR: "; echo -e "$1" # error messsage
  exit 1
}

function usage () {
  echo "Usage: $0 themes [set | ls]"
  echo "Commands:"
  echo "  set [theme]  | sets corresponding configs from [theme], if it exists "
  echo "  ls           | lists themes available to set to"
}

# set theme to $1
function try_set_theme () {
  local warn_list=("delete all symlinks referencing ${dir_triton}/current_theme contents" "delete all contents of ${dir_triton}/current_theme" "replace them with those seen in ${dir_themes}/$switchto")
  echo "Performing this action will: "
  for element in "${warn_list[@]}"; do
    echo " - $element"
  done
  if ask "Are you sure you want to do this?"; then
    set_theme $1
  fi
}

# =========== SCRIPT ============

case $1 in
  "--help" | "-h")
    usage; exit 0
    ;;
  "themes")
    if [ "$2" = "set" ]; then
      if themename_exists "$3"; then
        switchto="$3"
        try_set_theme "$3"
      elif [ -z "$3" ]; then
        error "no theme provided. Use \"$0 themes ls\" to see available themes."
      else
        error "theme \"$3\" does not exist in .themes directory: {dir_themes}.\nUse \"$0 themes ls\" to see available themes."
      fi
    elif [ "$2" = "ls" ]; then
      list_themes
    elif [ "$2" = "--help" ] || [ "$2" = "-h" ]; then
      usage; exit 0
    else
      usage; exit 1
    fi
    ;;
  *)
esac
