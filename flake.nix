{
  description = "Deadworks launcher built as a portable AppImage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The upstream repository has no flake of its own. `?dir=launcher` selects
    # the subdirectory that contains the Tauri application and `flake = false`
    # makes it plain source for us to build.
    deadworks = {
      url = "github:Deadworks-net/deadworks?dir=launcher&rev=585918857a7ad4a78a0d51476637f5621b9196df";
      flake = false;
    };

    # Turns a normal Nix package into a single-file, portable AppImage.
    nix-appimage = {
      url = "github:ralismark/nix-appimage";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, deadworks, nix-appimage }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          launcher = pkgs.callPackage ./package.nix { inherit deadworks; };

          appImage = nix-appimage.lib.${system}.mkAppImage {
            pname = "Deadworks";
            name = "Deadworks-${launcher.version}-${system}.AppImage";
            program = "${launcher}/bin/deadworks";
          };
        in
        {
          # `nix build` produces the AppImage file directly.
          default = appImage;
          appimage = appImage;

          # The underlying Nix-wrapped application, useful for development.
          deadworks = launcher;

          # Fast target for refreshing the frontend dependency hash.
          bunDeps = launcher.bunDeps;
        }
      );

      apps = forAllSystems (
        system:
        let
          appImage = self.packages.${system}.appimage;
        in
        {
          default = {
            type = "app";
            program = "${appImage}";
            meta.description = "Run the Deadworks launcher AppImage";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.callPackage ./shell.nix { inherit deadworks; };
        }
      );

      formatter = forAllSystems (system: (import nixpkgs { inherit system; }).nixfmt-tree);
    };
}
