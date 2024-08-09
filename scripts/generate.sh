#!/usr/bin/env sh
# shellcheck shell=sh # POSIX

set -e

# FIXME-QA(Krey): Uppercase variables are not yours to play with, those are reserved for the system!

# shellcheck source=./common.sh
. ./scripts/common.sh # Source common functionality

SCRIPT_DIR=$(dirname "$0")

[ -n "$1" ] || {
		echo "$0 <model> [firmware.rom] [ec.rom]" >&2
		exit 1
}

MODEL="$1"

unset BIOS_IMAGE
[ -z "$2" ] || {
		[ -f "$2" ] || die 1 "Could not find BIOS image '$2'"

		BIOS_IMAGE="$(realpath "$2")"
}


unset EC_ROM
[ -z "$3" ] || {
		[ -f "$3" ] || die 1 "Could not find EC ROM '$3'"

		EC_ROM="$(realpath "$3")"
}

[ -d "models/$MODEL" ] || {
		status "Generating for new model '$MODEL'"

		mkdir "models/$MODEL"

		# FIXME(Krey): Make this non-interactive
		read -rp "Manufacturer: " _mfr
		read -rp "Product name: " _name
		read -rp "Product version: " _version
		echo "# ${_mfr} ${_name} (${_version})" > "models/${MODEL}/README.md.in"
}

MODEL_DIR="$(realpath "models/$MODEL")"

status "Generating data for coreboot"

cd "$repoRoot/tools/coreboot-collector" || exit 1
cargo build --release

status "Running coreboot-collector"

sudo target/release/coreboot-collector > "$MODEL_DIR/coreboot-collector.txt"
cd - || exit 1

"$SCRIPT_DIR/coreboot-gpio.sh" "$MODEL_DIR/coreboot-collector.txt" > "$MODEL_DIR/gpio.c"
"$SCRIPT_DIR/coreboot-hda.sh" "$MODEL_DIR/coreboot-collector.txt" > "$MODEL_DIR/hda_verb.c"

[ -z "$BIOS_IMAGE" ] || {
		# Get the flash descriptor and Intel ME blobs
		make -C coreboot/util/ifdtool coreboot/util/ifdtool/ifdtool -x "$BIOS_IMAGE"

		# TODO(S76): Don't hardcode flash region index
		mv flashregion_0_flashdescriptor.bin "$MODEL_DIR/fd.rom"
		mv flashregion_2_intel_me.bin "$MODEL_DIR/me.rom"
		rm -f flashregion_*.bin
}

# FIXME-QA(Krey): The conditionals below are terrible

# Get the Video BIOS Table and GOP driver for Intel systems
if sudo [ -e /sys/kernel/debug/dri/1/i915_vbt ]; then
		sudo cat /sys/kernel/debug/dri/1/i915_vbt > "$MODEL_DIR/vbt.rom"

		INTEL_GOP_DRIVER_GUID="7755CA7B-CA8F-43C5-889B-E1F59A93D575"
		EXTRACT_DIR="extract"

		if [ -n "$BIOS_IMAGE" ]; then
				if "$SCRIPT_DIR/extract.sh" "$BIOS_IMAGE" "$INTEL_GOP_DRIVER_GUID" -o "$EXTRACT_DIR" > /dev/null
				then
						cp -v "$(find "$EXTRACT_DIR" | grep IntelGopDriver | grep PE32 | grep body.bin)" "$MODEL_DIR/IntelGopDriver.efi"
						rm -rf "$EXTRACT_DIR"
				else
						echo "IntelGopDriver not present in firmware image"
				fi
		fi
fi

# XXX: More reliable way to determine if system has an EC?
DMI_CHASSIS_TYPE="$(cat /sys/class/dmi/id/chassis_type)"

if [ "$DMI_CHASSIS_TYPE" = "9" ] || [ "$DMI_CHASSIS_TYPE" = "10" ]
then
		if [ -n "$EC_ROM" ]; then
				echo "Using proprietary EC ROM file"
				cp "$EC_ROM" "$MODEL_DIR/ec.rom"
		else
				echo "Generating output for System76 EC firmware"
				cd "$repoRoot/ec/ecspy" || exit 1
				cargo build --release
				# TODO(S76): Set backlights and fans to max and restore after
				sudo target/release/ecspy > "$MODEL_DIR/ecspy.txt"
				# Strip EC RAM entries from output
				sed -i '/^0x/d' "$MODEL_DIR/ecspy.txt"
				cd - || exit 1
		fi
fi

"$SCRIPT_DIR/readmes.sh"
