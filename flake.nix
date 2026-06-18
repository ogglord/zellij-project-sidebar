{
  description = "Zellij session sidebar plugin with shell activity tracking";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              rustup
              stdenv.cc
              lld
              pkg-config
            ];
            shellHook = ''
              rustup toolchain list 2>/dev/null | grep -q '(default)' || rustup default stable
              rustup target list --installed 2>/dev/null | grep -q wasm32-wasip1 \
                || rustup target add wasm32-wasip1
            '';
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          wasiPkgs = pkgs.pkgsCross.wasi32;

          # The native init binary (zsh/bash hook generator)
          # Built from src/init/ — a separate crate with no dependencies
          initBinary = pkgs.rustPlatform.buildRustPackage {
            pname = "zellij-ssidebar";
            version = "unstable-${self.lastModifiedDate or "unknown"}";
            src = ./src/init;
            cargoLock.lockFile = ./src/init/Cargo.lock;
            doCheck = false;
            meta = {
              description = "Shell hook generator for zellij-ssidebar";
              license = pkgs.lib.licenses.mit;
            };
          };

          # The WASM plugin
          wasmPlugin = wasiPkgs.rustPlatform.buildRustPackage {
            pname = "zellij-ssidebar";
            version = "unstable-${self.lastModifiedDate or "unknown"}";
            src = self;
            cargoLock.lockFile = ./Cargo.lock;
            nativeBuildInputs = [ wasiPkgs.lld ];
            env.RUSTFLAGS = "-C linker=wasm-ld";
            installPhase = ''
              runHook preInstall
              wasm=$(find target -name 'zellij-ssidebar.wasm' -path '*/release/*' | head -1)
              [ -n "$wasm" ] || { echo "zellij-ssidebar.wasm not found"; exit 1; }
              install -m755 "$wasm" "$out"
              runHook postInstall
            '';
            doCheck = false;
            meta = {
              description = "Zellij sidebar plugin: project list with AI and shell activity indicators";
              license = pkgs.lib.licenses.mit;
            };
          };
        in
        {
          default = initBinary;
          zellij-ssidebar = initBinary;
          zellij-ssidebar-plugin = wasmPlugin;
        }
      );

      # NixOS module — primary interface
      nixosModules.default =
        { config, lib, pkgs, ... }:
        import ./nix/module.nix {
          inherit config lib pkgs;
          package = self.packages.${pkgs.system}.zellij-ssidebar;
          pluginPackage = self.packages.${pkgs.system}.zellij-ssidebar-plugin;
        };

      # Home Manager module — for those who prefer user-level config
      homeManagerModules.default =
        { config, lib, pkgs, ... }:
        import ./nix/module.nix {
          inherit config lib pkgs;
          package = self.packages.${pkgs.system}.zellij-ssidebar;
          pluginPackage = self.packages.${pkgs.system}.zellij-ssidebar-plugin;
        };
    };
}
