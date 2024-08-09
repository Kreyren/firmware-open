#!/usr/bin/env bash
# shellcheck shell=sh # POSIX
# SPDX-License-Identifier: GPL-3.0-only

set -e # Exit on false return

# shellcheck source=./common.sh
. ./scripts/common.sh # Source common functionality

status "Installing system build dependencies"

# Install dependencies per distro
case "$distro" in
	debian:*)
		sudo apt-get --quiet update
		sudo apt-get --quiet install \
			--no-install-recommends \
			--assume-yes \
			build-essential \
			ccache \
			cmake \
			curl \
			dosfstools \
			flashrom \
			git-lfs \
			libncurses-dev \
			libssl-dev \
			libudev-dev \
			mtools \
			parted \
			pkgconf \
			python-is-python3 \
			python3-distutils \
			uuid-dev \
			zlib1g-dev
	;;
	fedora:*)
		sudo dnf group install c-development
		sudo dnf install \
			--assumeyes \
			ccache \
			cmake \
			curl \
			dosfstools \
			flashrom \
			git-lfs \
			libuuid-devel \
			mtools \
			ncurses-devel \
			openssl-devel \
			parted \
			patch \
			python-unversioned-command \
			python3 \
			systemd-devel \
			zlib-devel
	;;
	arch:*)
		sudo pacman -S \
			--noconfirm \
			ccache \
			cmake \
			curl \
			dosfstools \
			flashrom \
			git-lfs \
			mtools \
			ncurses \
			parted \
			patch \
			python \
			python-distutils-extra \
			systemd-libs
	;;
	NixOS:*)
		[ -n "$nixInDevShell" ] || die 1 "When running on NixOS please make sure that you are using the provided development shell and then retry this script"
	;;
	*) die 1 "Distribution '$distro' is not implemented, please add support in $0"
esac

# Don't run on Jenkins
[ -n "$CI" ] || {
	# FIXME(Krey): Do not change git configuration on NixOS
	# status "Installing GIT LFS hooks"
	# git lfs install

	# msg "Downloading GIT LFS artifacts"
	# git lfs pull
	:
}

msg "Initializing submodules"
# FIXME(Krey): Do not mess with submodules if they are already fetched
# git submodule update --init --recursive --checkout --progress

msg "Building coreboot toolchains"
./scripts/coreboot-sdk.sh

msg "Installing Rust toolchain and components"
./scripts/install-rust.sh

msg "Installing EC dependencies"

# FIXME(Krey): Why are we depending on relative paths?
# FIXME-QA(Krey): script/deps.sh does not exists
# cd ec || die 1 "Failed to change directory to 'ec'"
# ./scripts/deps.sh
# cd - || die 1 "Failed to change back to the previous directory"

success "Successfully installed dependencies"

echo "Ready to run ./scripts/build.sh [model]" >&2
