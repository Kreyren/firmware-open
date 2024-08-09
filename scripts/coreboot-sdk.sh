#!/usr/bin/env sh
# shellcheck shell=sh # POSIX

# Build the coreboot toolchains

set -e

# shellcheck source=./common.sh
. ./scripts/common.sh # Source common functionality

case "$distro" in
	arch:*)
		sudo pacman -S --noconfirm \
			bison \
			bzip2 \
			ca-certificates \
			curl \
			flex \
			gcc \
			gcc-ada \
			make \
			nss \
			patch \
			tar \
			xz \
			zlib
	;;
	fedora:*)
		sudo dnf install --assumeyes \
			bison \
			bzip2 \
			ca-certificates \
			curl \
			flex \
			gcc \
			gcc-c++ \
			gcc-gnat \
			make \
			nss-devel \
			patch \
			tar \
			xz \
			zlib-devel
	;;
	NixOS:*)
		[ -n "$nixInDevShell" ] || die 1 "When running on NixOS please make sure that you are using the provided development shell and then retry this script"
	;;
	ubuntu:*)
		sudo apt-get --quiet update
		sudo apt-get --quiet install --no-install-recommends --assume-yes \
			bison \
			bzip2 \
			ca-certificates \
			curl \
			flex \
			g++ \
			gcc \
			gnat \
			libnss3-dev \
			make \
			patch \
			tar \
			xz-utils \
			zlib1g-dev
	;;
	*) die 1 "Distribution '$distro' is not implemented, please add support in $0"
esac

nproc="$(nproc)"

case "$distro" in
	NixOS:*) true ;; # Do not build the toolchain on NixOS as it's already provided in devshell
	arch:*|debian:*|fedora:*|ubuntu:*)
		make -C coreboot CPUS="$nproc" crossgcc-i386
		make -C coreboot CPUS="$nproc" crossgcc-x64
		make -C coreboot gitconfig
	;;
	*) die 1 "Distro '$distro' is not implemented in $0, please contribute support"
esac
