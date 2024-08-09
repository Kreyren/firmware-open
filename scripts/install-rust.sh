#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# shellcheck shell=sh # POSIX

# Install Rust, along with the pinned toolchain.

set -e

# shellcheck source=./common.sh
. ./scripts/common.sh # Source common functionality

case "$distro" in
	NixOS:*)
		[ -n "$nixInDevShell" ] || die 1 "When running on NixOS please make sure that you are using the provided development shell and then retry this script"
	;;
	*)
		# FIXME(Krey): Original code that badly manages rust and should be refactored, but i am on NixOS so i don't care to refactor it
		RUSTUP_NEW_INSTALL=0

		# NOTE: rustup is used to allow multiple toolchain installations.
		command -v rustup >/dev/null 2>&1 || {
			RUSTUP_NEW_INSTALL=1
			curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
				| sh -s -- -y --default-toolchain stable

				# shellcheck disable=SC1091 # Disable valid check for looking at env file in user directoty (bad)
			. "$HOME/.cargo/env"
		}

		# XXX: rustup has no command to install a toolchain from a TOML file.
		# Rely on the fact that `show` will install the default toolchain.
		rustup show

		[ "$RUSTUP_NEW_INSTALL" != 1 ] || {
			printf "\e[33m>> rustup was just installed. Ensure cargo is on the PATH with:\e[0m\n"
			printf "    source ~/.cargo/env\n\n"
		}
esac