{
  pkgs ? import ./nixpkgs.nix { },
}:
pkgs.rust-bin.nightly."2026-01-22".default.override {
  extensions = [
    "rust-src"
    "rust-analyzer"
    "clippy"
  ];
}
