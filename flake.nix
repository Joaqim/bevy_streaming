# Zero-input flake — nixpkgs and rust-overlay pinned via npins.
# See hall-of-hammers/flake.nix and juspay/kolu/flake.nix for pattern origin.
{
  outputs =
    _:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f (import ./nix/nixpkgs.nix { inherit system; });
          }) systems
        );
    in
    {
      nixosModules.pixelstreaming-signaller = import ./nix/module.nix;

      packages = eachSystem (
        pkgs:
        let
          bevy-streaming = import ./default.nix { inherit pkgs; };
        in
        {
          default = bevy-streaming;
          pixelstreaming-signaller = pkgs.pixelstreaming-signaller;
        }
      );

      devShells = eachSystem (pkgs: {
        default = import ./shell.nix { inherit pkgs; };
      });
    };
}
