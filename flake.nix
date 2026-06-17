{
  description = "Zellij project sidebar plugin";

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
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          wasiPkgs = pkgs.pkgsCross.wasi32;
        in
        {
          default = wasiPkgs.rustPlatform.buildRustPackage {
            pname = "zellij-project-sidebar";
            version = "unstable-${self.lastModifiedDate or "unknown"}";

            src = self;
            cargoLock.lockFile = ./Cargo.lock;

            # wasm-ld fix: pkgsCross.wasi32.rustPlatform injects wasm32-unknown-wasi-cc as
            # the linker, but Rust's wasm32-wasip1 target needs wasm-ld directly.
            # See: https://github.com/NixOS/nixpkgs/pull/463720
            nativeBuildInputs = [ wasiPkgs.lld ];
            env.RUSTFLAGS = "-C linker=wasm-ld";

            installPhase = ''
              runHook preInstall
              wasm=$(find target -name 'zellij-project-sidebar.wasm' -path '*/release/*' | head -1)
              [ -n "$wasm" ] || { echo "zellij-project-sidebar.wasm not found in target/release"; exit 1; }
              install -m755 "$wasm" "$out"
              runHook postInstall
            '';

            doCheck = false;

            meta = {
              description = "Zellij sidebar plugin: project list with AI activity indicators";
              license = pkgs.lib.licenses.mit;
            };
          };
        }
      );
    };
}
