{
  pkgs ? import ./nix/nixpkgs.nix { },
  package ? import ./default.nix { inherit pkgs; },
}:
let
  allRuntimeLibs = package.passthru.gstPlugins ++ package.passthru.runtimeLibs;
  libPath = pkgs.lib.makeLibraryPath allRuntimeLibs;
  gstPluginPath = pkgs.lib.makeSearchPath "lib/gstreamer-1.0" package.passthru.gstPlugins;
in
pkgs.mkShell {
  inputsFrom = [ package ];
  buildInputs = [
    pkgs.pixelstreaming-signaller
  ];

  LD_LIBRARY_PATH = libPath;
  GST_PLUGIN_SYSTEM_PATH_1_0 = gstPluginPath;

  shellHook = ''
    echo "bevy_streaming development environment"
    echo "Run 'cargo run --example simple' to start the streaming example"
    echo "Run 'pixelstreaming-signaller --streamer_port 8888 --player_port 8080' for signalling"
  '';
}
