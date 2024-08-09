#!/usr/bin/env sh
# shellcheck shell=sh # POSIX

msg() { printf "\x1B[1m%s\x1B[0m\n" "$1" >&2 ;}

status() { printf "\x1B[1m%s\x1B[0m\n" "$1" >&2 ;}

die() { printf "FATAL: %s\n" "$2"; exit "${1:-"1"}" ;}

success() { printf "\x1B[32m%s\n" "$1" ;}

# shellcheck disable=SC2155 # Used in other shell scripts
export repoRoot="$(git rev-parse --show-toplevel)"

which lsb_release 1>/dev/null || die 3 "Required command 'lsb_release' is not executable in the current environment, please install it to proceed"

# shellcheck disable=SC2155 # Used in other shell scripts
export distro="$(lsb_release --id --short | sed 's#\"##g'):$(lsb_release --release --short | sed 's#\"##g')"
