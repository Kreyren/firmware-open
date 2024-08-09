#!/usr/bin/env sh
# shellcheck shell=sh # POSIX

set -e

# FIXME-QA(Krey): Lacks check->runtime integration
# FIXME-QA(Krey): It's also uses `rm -rf` too much, it's disaster waiting to happen`

# shellcheck source=./common.sh
. ./scripts/common.sh # Source common functionality

# Get the required toolchain in PATH
case "$distro" in
	NixOS:*)
		# Do NOT touch the PATH on NixOS, the coreboot toolchain is provided as a package to work with coreboot
		[ -n "$nixInDevShell" ] || die 1 "When running on NixOS please make sure that you are using the provided development shell and then retry this script"
	;;
	arch:*|debian:*|fedora:*|ubuntu:*)
		export XGCCPATH="${XGCCPATH:-"$PWD/coreboot/util/crossgcc/xgcc/bin"}"

		# FIXME-QA(Krey): Pretty sure debian devs would not be happy about the sbin addition
		export PATH="$XGCCPATH:$PATH:/usr/sbin"
	;;
	*) die 1 "Distribution '$distro' is not implemented in $0, please contribute it"
esac

[ -n "$1" ] || {
	echo "$0 <model>" >&2
	exit 1
}

MODEL="$1"

[ -d "models/$MODEL" ] || die 1 "Model '$MODEL' is not implemented"

MODEL_DIR="$(realpath "models/$MODEL")"

DATE="$(git show --format="%cd" --date="format:%Y-%m-%d" --no-patch --no-show-signature)"
REV="$(git describe --always --dirty --abbrev=7)"
VERSION="${DATE}_$REV"

status "Building '${VERSION}' for '${MODEL}'"

status "Cleaning the build directory"

# FIXME-QA(Krey): Not sure why is there this mkdir
mkdir -p build

BUILD="$(realpath "build/$MODEL")"
rm -rf "$BUILD"
mkdir -p "$BUILD"

UEFIPAYLOAD="$BUILD/UEFIPAYLOAD.fd"
COREBOOT="$BUILD/firmware.rom"
USB="$BUILD/usb.img"
EDK2_ARGS="-D SHELL_TYPE=NONE -D SOURCE_DEBUG_ENABLE=FALSE"

# Rebuild firmware-setup (used by edk2)
touch apps/firmware-setup/Cargo.toml
make -C apps/firmware-setup
EDK2_ARGS="$EDK2_ARGS -D FIRMWARE_OPEN_FIRMWARE_SETUP=\"firmware-setup/firmware-setup.inf\""

# Rebuild gop-policy (used by edk2)
if [ -e "$MODEL_DIR/IntelGopDriver.inf" ] && [ -e "$MODEL_DIR/vbt.rom" ]; then
	touch apps/gop-policy/Cargo.toml
	FIRMWARE_OPEN_VBT="$MODEL_DIR/vbt.rom" make -C apps/gop-policy
	EDK2_ARGS="$EDK2_ARGS -D FIRMWARE_OPEN_GOP_POLICY=\"gop-policy/gop-policy.inf\" -D FIRMWARE_OPEN_GOP=\"IntelGopDriver.inf\""
fi

# Add any arguments in edk2.config
[ ! -e "$MODEL_DIR/edk2.config" ] || {
	while read -r line
	do
		# shellcheck disable=SC2249 # Lets not add default case here as it increases complexity
		case "$line" in "#"*) EDK2_ARGS="$EDK2_ARGS -D $line"; esac
	done < "$MODEL_DIR/edk2.config"
}

appsDir="$(realpath "$repoRoot/apps")"

# Rebuild UefiPayloadPkg using edk2
PACKAGES_PATH="$MODEL_DIR:$appsDir" ./scripts/_build/edk2.sh "$UEFIPAYLOAD" "$EDK2_ARGS"

# Rebuild coreboot
# NOTE: coreboot expects paths to be relative to it
FIRMWARE_OPEN_MODEL_DIR="../models/$MODEL" \
FIRMWARE_OPEN_UEFIPAYLOAD="$UEFIPAYLOAD" \
KERNELVERSION="$VERSION" \
	./scripts/_build/coreboot.sh \
		"$MODEL_DIR/coreboot.config" \
		"$COREBOOT"

# Rebuild EC firmware for System76 EC models
if [ ! -e  "$MODEL_DIR/ec.rom" ] && [ -e "$MODEL_DIR/ec.config" ]; then
	env VERSION="$VERSION" \
		./scripts/_build/ec.sh \
			"$MODEL_DIR/ec.config" \
			"$BUILD/ec.rom"
fi

[ "$MODEL" = "qemu" ] || {
	# Rebuild firmware-update
	export BASEDIR="system76_${MODEL}_$VERSION"

	cd "$appsDir/firmware-update" || die 1 "Failed to change directory to '$appsDir/firmware-update'"
		rm -rf "$repoRoot/build/x86_64-unknown-uefi"
		make "$repoRoot/build/x86_64-unknown-uefi/boot.img"
		cp -v "$repoRoot/build/x86_64-unknown-uefi/boot.img" "$USB.partial"
	cd - || die 1 "Failed to change directory back to the previous"

	# FIXME-QA(Krey): We should be asking if we can copy things to USB

	# Copy firmware to USB image
	mmd -i "$USB.partial@@1M" "::$BASEDIR/firmware"
	mcopy -v -i "$USB.partial@@1M" "$COREBOOT" "::$BASEDIR/firmware/firmware.rom"

	if [ -e "$BUILD/ec.rom" ]; then
		mcopy -v -i "$USB.partial@@1M" "$BUILD/ec.rom" "::$BASEDIR/firmware/ec.rom"
	elif [ -e "$MODEL_DIR/ec.rom" ]; then
		mcopy -v -i "$USB.partial@@1M" "$MODEL_DIR/ec.rom" "::$BASEDIR/firmware/ec.rom"
	fi

	[ ! -e "$MODEL_DIR/uecflash.efi" ] || mcopy -v -i "$USB.partial@@1M" "$MODEL_DIR/uecflash.efi" "::$BASEDIR/firmware/uecflash.efi"

	mv -v "$USB.partial" "$USB"
}

status "Built '$VERSION' for '$MODEL'"
