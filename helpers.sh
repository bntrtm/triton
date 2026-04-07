#!/usr/bin/env bash

log() {
  local level=$1
  local message=$2
  echo "[${1}] ${2}"
}

error() {
  log "ERROR" "$1"
  exit 1
}

warn() {
  log "WARN" "$1"
}

info() {
  log "INFO" "$1"
}

debug() {
  log "DEBUG" "$1"
}

get_filename() {
  local filename=$1
}

# get_basename uses parameter expansion to return all characters
# right of the last '/' character found within the given argument.
get_basename() {
  local arg=$1
  echo ${arg##*/}
}

# get_dirname uses parameter expansion to return all characters
# left of the last '/' character found within the given argument.
get_dirname() {
  local arg=$1
  echo ${arg%/*}
}

# read user yes-or-no input
ask() {
  read -p "$1 (Y/n): " response
  [[ -z "$response" ]] || [[ "$response" = "Y" ]]
}

# run until user-specified directory for $1 does indeed exist, then set ref $2 to that path
askpath() {
  declare -n ref=$2
  until [[ -d "${ref}" ]]; do
    read -e -p "Provide a directory path for $1: " -i "$HOME/" response
    ref="${response}"
    if [[ ! -d "${ref}" ]]; then
      warn "$ref is not a valid directory."
    fi
  done
}

# check that command can run; used to check for dependencies
# $1 is the command to check for; $2 is a formal name for the program to install
check_command() {
  if ! command -v "$1" &>/dev/null; then
    if [[ -z "$2" ]]; then
      arn "check_command: \"$1\" not a valid command; corresponding program may not be installed."
      return 1
    else
      warn "check_command: \"$1\" not a valid command; $2 is not installed."
      return 1
    fi
  else
    return 0
  fi
}
