#!/bin/bash

function error () {
  echo -n "ERROR: "; echo -e "$1" # error message
  exit 1
}

# read user yes-or-no input
function ask () {
  read -p "$1 (Y/n): " response
  [ -z "$response" ] || [ "$response" = "Y" ]
}

# run until user-specified directory for $1 does indeed exist, then set ref $2 to that path
function askpath () {
  declare -n ref=$2
  until test -d "${ref}"; do
    read -e -p "Provide a directory path for $1: " -i "$HOME/" response
    ref="${response}"
    if ! test -d "${ref}"; then
      echo "$ref is not a valid directory."
    fi
  done
}

# check that command can run; used to check for dependencies
# $1 is the command to check for; $2 is a formal name for the program to install
function check_command () {
  if ! command -v stow &> /dev/null; then
    if [ -z $2]; then
      echo "check_command: \"$1\" not a valid command; corresponding program may not be installed."
      return 1
    else
      echo "check_command: \"$1\" not a valid command;  $2 is not installed."
      return 1
    fi
  else
    return 0
  fi
}

#var1="replace_this_value"
#askpath "dotfiles" var1
#echo "$var1"
