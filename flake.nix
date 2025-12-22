{
  description = "Rust + Android (NDK) dev shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };
        
        # Import x86_64 packages for Android NDK support
        pkgs-x86_64 = import nixpkgs {
          system = "x86_64-linux";
          overlays = overlays;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };
        
        ndkVersion = "27.3.13750724";
        androidComposition = pkgs-x86_64.androidenv.composeAndroidPackages {
          platformVersions = [ "34" ];
		  cmdLineToolsVersion = "11.0";
          buildToolsVersions = [ "34.0.0" ];
          includeSources = false;
          includeNDK = true;
          inherit ndkVersion;
        };
        rustToolchain = pkgs.rust-bin.stable."1.90.0".default.override {
          extensions = [ "rust-src" "clippy" "rustfmt" ];
          targets = [ "aarch64-linux-android" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust tooling
            rustToolchain
            cargo-ndk
            cargo-watch
            cargo-edit

			# GPU
			vulkan-loader
			vulkan-headers
			vulkan-tools
			vulkan-validation-layers
			glslang
			spirv-tools
			shaderc

			# Wayland
			wayland
			wayland-protocols
            libxkbcommon

            # Android
            android-tools
            androidComposition.androidsdk

			# Java
			jdk17
			gradle

            # Build essentials
            pkg-config
            openssl.dev
            clang
            gcc
            gnumake
            glibc

			# Emulation
			qemu
          ];

          # Set library paths
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.wayland
            pkgs.libxkbcommon
            pkgs.vulkan-loader
          ];

          shellHook = ''
            export VK_LAYER_PATH="${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d"

			export ANDROID_SDK_ROOT=${androidComposition.androidsdk}/libexec/android-sdk
			export ANDROID_NDK_HOME=${androidComposition.androidsdk}/libexec/android-sdk/ndk/${ndkVersion}
			export ANDROID_HOME=${androidComposition.androidsdk}/libexec/android-sdk

			export RUST_SRC_PATH="${rustToolchain}/lib/rustlib/src/rust/library"
			export JAVA_HOME=${pkgs.jdk17}
			
			# Provide x86_64 glibc for QEMU to emulate x86_64 binaries on ARM64
			export QEMU_LD_PREFIX=${pkgs-x86_64.glibc}
			export LD_LIBRARY_PATH=${pkgs-x86_64.glibc}/lib64:${pkgs-x86_64.lib.makeLibraryPath [
			  pkgs-x86_64.glibc
			  pkgs-x86_64.openssl
			]}:$LD_LIBRARY_PATH

		  '';
        };
      });
}
