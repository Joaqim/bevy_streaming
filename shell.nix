{
  pkgs ? import ./nix/nixpkgs.nix { },
  package ? import ./default.nix { inherit pkgs; },
}:
let
  libPath = pkgs.lib.makeLibraryPath package.passthru.runtimeLibs;

  gstPlugins = with pkgs.gst_all_1; [
    gstreamer.out
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-plugins-rs
  ];
  gstPluginPath = pkgs.lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins;

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
