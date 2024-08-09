{
	description = "Firmware Open";

	inputs = {
		# Release inputs
			nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*.tar.gz";
			nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";


		# Principle inputs
			nixos-flake.url = "github:srid/nixos-flake";
			flake-parts.url = "github:hercules-ci/flake-parts";
			mission-control.url = "github:Platonic-Systems/mission-control";

			flake-root.url = "github:srid/flake-root";

		nixos-generators = {
			url = "github:nix-community/nixos-generators";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs @ { self, ... }:
		inputs.flake-parts.lib.mkFlake { inherit inputs; } {
			imports = [
				./tasks # Include Tasks
				inputs.flake-root.flakeModule
				inputs.mission-control.flakeModule
			];

			# Set Supported Systems
			systems = [
				"x86_64-linux"
				"aarch64-linux"
				"riscv64-linux"
				"armv7l-linux"
			];

			perSystem = { system, config, inputs', ... }: {
				devShells.default = inputs.nixpkgs.legacyPackages.${system}.mkShell {
					name = "firmware-open-devshell";
					nativeBuildInputs = [
						inputs.nixpkgs.legacyPackages.${system}.bashInteractive # For terminal
						inputs.nixpkgs.legacyPackages.${system}.nil # Needed for linting
						inputs.nixpkgs.legacyPackages.${system}.nixpkgs-fmt # Nixpkgs formatter
						inputs.nixpkgs.legacyPackages.${system}.git # Working with the codebase
						inputs.nixpkgs.legacyPackages.${system}.nano # Editor to work with the codebase in cli
						inputs.nixpkgs.legacyPackages.${system}.shellcheck # Linting shell files

						inputs.nixpkgs.legacyPackages.${system}.fira-code # For liquratures in code editors

						inputs.nixpkgs.legacyPackages.${system}.flashrom

						inputs.nixos-generators.packages.${system}.nixos-generate

						inputs.nixpkgs-unstable.legacyPackages.${system}.coreboot-toolchain.x64
						inputs.nixpkgs-unstable.legacyPackages.${system}.coreboot-toolchain.i386
						inputs.nixpkgs.legacyPackages.${system}.pkg-config
						inputs.nixpkgs.legacyPackages.${system}.openssl
						inputs.nixpkgs.legacyPackages.${system}.bison
						inputs.nixpkgs.legacyPackages.${system}.flex
						inputs.nixpkgs.legacyPackages.${system}.zlib
						inputs.nixpkgs.legacyPackages.${system}.gnum4
						inputs.nixpkgs.legacyPackages.${system}.gnat
						inputs.nixpkgs.legacyPackages.${system}.ncurses
						inputs.nixpkgs.legacyPackages.${system}.libuuid # Needed by EDK2 payload
						inputs.nixpkgs.legacyPackages.${system}.imagemagick
						inputs.nixpkgs.legacyPackages.${system}.python3
						inputs.nixpkgs.legacyPackages.${system}.ccache
						inputs.nixpkgs.legacyPackages.${system}.cmake
						inputs.nixpkgs.legacyPackages.${system}.curl
						inputs.nixpkgs.legacyPackages.${system}.dosfstools
						inputs.nixpkgs.legacyPackages.${system}.git-lfs
						inputs.nixpkgs.legacyPackages.${system}.mtools
						inputs.nixpkgs.legacyPackages.${system}.ncurses
						inputs.nixpkgs.legacyPackages.${system}.parted
						inputs.nixpkgs.legacyPackages.${system}.gnupatch # patch
						inputs.nixpkgs.legacyPackages.${system}.systemdLibs
						inputs.nixpkgs.legacyPackages.${system}.lsb-release
						inputs.nixpkgs.legacyPackages.${system}.bzip2
						inputs.nixpkgs.legacyPackages.${system}.cacert # ca-certificates
						inputs.nixpkgs.legacyPackages.${system}.curl
						inputs.nixpkgs.legacyPackages.${system}.flex
						inputs.nixpkgs.legacyPackages.${system}.libgcc # g++ and gcc
						inputs.nixpkgs.legacyPackages.${system}.gnat
						inputs.nixpkgs.legacyPackages.${system}.gnumake
						inputs.nixpkgs.legacyPackages.${system}.gnupatch # patch
						inputs.nixpkgs.legacyPackages.${system}.gnutar # tar
						inputs.nixpkgs.legacyPackages.${system}.xz
						inputs.nixpkgs.legacyPackages.${system}.rustc
						inputs.nixpkgs.legacyPackages.${system}.cargo
						inputs.nixpkgs.legacyPackages.${system}.uefitool
					];
					inputsFrom = [
						config.mission-control.devShell
						config.flake-root.devShell
					];
					# Environmental Variables
					#VARIABLE = "value"; # Comment
					nixInDevShell = 0;
				};

				formatter = inputs.nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
			};
		};
}
