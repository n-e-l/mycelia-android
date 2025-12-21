{
  description = "Rust development environment";

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
        };
        rustToolchain = pkgs.rust-bin.stable."1.90.0".default.override {
          extensions = [ "rust-src" "clippy" "rustfmt" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust toolchain
            rustToolchain
            
            # Development tools
            rust-analyzer
            cargo-watch
            cargo-edit
            pkg-config

			# GPU
			vulkan-loader
			vulkan-headers
			vulkan-tools
			vulkan-validation-layers
			glslang
			spirv-tools

			# Wayland
            wayland
            wayland-protocols
            libxkbcommon

			# Network
			openssl.dev
          ];

          shellHook = ''
            export OPENSSL_DIR="${pkgs.openssl.out}"
            export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
            export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.wayland}/lib/pkgconfig:${pkgs.libxkbcommon}/lib/pkgconfig"

            # Vulkan validation layers
            export VK_LAYER_PATH="${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d"

            # Rust source (for rust-analyzer)
            export RUST_SRC_PATH="${rustToolchain}/lib/rustlib/src/rust/library"

            # Wayland backend for winit
            export WINIT_UNIX_BACKEND=wayland

			export LD_LIBRARY_PATH="${pkgs.wayland}/lib:${pkgs.libxkbcommon}/lib:${pkgs.vulkan-loader}/lib:${pkgs.xorg.libxcb}/lib:$LD_LIBRARY_PATH"
          '';
        };
      });
}
