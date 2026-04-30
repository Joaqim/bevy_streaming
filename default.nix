{
  pkgs ? import ./nix/nixpkgs.nix { },
}:
let
  runtimeLibs =
    with pkgs;
    [
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-plugins-rs
      openssl
      vulkan-loader
    ]
    ++ lib.optionals stdenv.isLinux [
      alsa-lib
      udev
      wayland
      libxkbcommon
      libx11
      libxcursor
      libxi
      libxrandr
    ];

  gstBuildDeps = with pkgs.gst_all_1; [
    gstreamer.dev
    gst-plugins-base.dev
    gst-plugins-bad.dev
  ];

  buildInputs = [ pkgs.pkg-config pkgs.openssl.dev ] ++ runtimeLibs ++ gstBuildDeps;

  rustToolchain = import ./nix/rust-toolchain.nix { inherit pkgs; };

  nativeBuildInputs = [
    rustToolchain
    pkgs.pkg-config
    pkgs.makeWrapper
  ];

  cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  inherit (cargoToml.package) version;
  pname = cargoToml.package.name;
in
(pkgs.rustPlatform.buildRustPackage {
  inherit pname version;

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
    allowBuiltinFetchGit = true;
  };

  cargoBuildFlags = [ "--examples" ];

  postInstall = ''
    install -Dm755 target/*/release/examples/simple $out/bin/simple
    wrapProgram $out/bin/simple \
      --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs} \
      --prefix GST_PLUGIN_PATH : ${pkgs.lib.makeSearchPath "lib/gstreamer-1.0" runtimeLibs}
  '';

  inherit buildInputs nativeBuildInputs;

  doCheck = false;

  meta = with pkgs.lib; {
    description = cargoToml.package.description or "";
    homepage = cargoToml.package.homepage or "";
    license = with licenses; [ mit ];
    mainProgram = "simple";
  };
}).overrideAttrs
  (old: {
    passthru = (old.passthru or { }) // {
      inherit runtimeLibs;
    };
  })
