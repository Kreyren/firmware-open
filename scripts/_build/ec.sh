#!/usr/bin/env sh
# shellcheck shell=sh # POSIX

set -e

if [ -z "$1" ] || [ ! -e "$1" ] || [ -z "$2" ]; then
	echo "$0 <config> <output>" >&2
	exit 1
fi

unset EC_ARGS
while read -r line; do
	case "$line" in "#"*) EC_ARGS="$EC_ARGS $line"; esac
done < "$1"

BUILD_DIR="build"

make -C ec BUILD="$BUILD_DIR" clean
make -C ec VERSION="$VERSION" "$EC_ARGS" BUILD="$BUILD_DIR" -j "$(nproc)"
cp -v "ec/$BUILD_DIR/ec.rom" "$2"
