{
  pkgs ? import ./nix/nixpkgs.nix { },
}:
let
  gstPlugins =
    with pkgs.gst_all_1;
    [
      gstreamer.out
      gst-plugins-base
      gst-plugins-good
      gst-plugins-bad
      gst-plugins-ugly
      gst-plugins-rs
      pkgs.libnice.out
    ];

  runtimeLibs =
    with pkgs;
    [
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

  buildInputs =
    [ pkgs.pkg-config pkgs.openssl.dev ]
    ++ gstPlugins
    ++ runtimeLibs
    ++ gstBuildDeps;

  rustToolchain = import ./nix/rust-toolchain.nix { inherit pkgs; };

  nativeBuildInputs = [
    rustToolchain
    pkgs.pkg-config
    pkgs.makeWrapper
  ];

  cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  inherit (cargoToml.package) version;
  pname = cargoToml.package.name;

  allRuntimeLibs = gstPlugins ++ runtimeLibs;
  gstPluginPath = pkgs.lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins;
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
      --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath allRuntimeLibs} \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${gstPluginPath}
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
      inherit gstPlugins runtimeLibs;
    };
  })
