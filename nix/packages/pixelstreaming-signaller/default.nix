# Package derivation for the PixelStreaming signalling server.
#
# Builds the SignallingWebServer and Frontend from EpicGames/PixelStreamingInfrastructure.
# The signalling server relays WebRTC negotiation between the game (streamer)
# and browser clients (players), and serves the web player frontend.
#
# Source is pinned via npins (see npins/sources.json, key: "pixelstreaming").
{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs,
}:
let
  sources = import ../../../npins;
  src = sources.pixelstreaming;
  version = "5.7";

  frontend = buildNpmPackage {
    pname = "pixelstreaming-frontend";
    inherit version src;
    sourceRoot = "source/Frontend/implementations/typescript";
    postPatch = ''
      cp ${./frontend-package-lock.json} package-lock.json
    '';
    npmDepsHash = lib.fakeHash;
    buildPhase = ''
      npx webpack --config webpack.prod.js
    '';
    installPhase = ''
      mkdir -p $out
      cp -r dist/* $out/
    '';
  };

in
buildNpmPackage {
  pname = "pixelstreaming-signaller";
  inherit version src;

  sourceRoot = "source/SignallingWebServer";
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';
  npmDepsHash = lib.fakeHash;

  buildPhase = ''
    npm run build
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib,www}
    cp -r dist node_modules package.json $out/lib/
    cp -r ${frontend}/* $out/www/

    cat > $out/bin/pixelstreaming-signaller <<WRAPPER
    #!${stdenv.shell}
    exec ${nodejs}/bin/node $out/lib/dist/index.js "\$@"
    WRAPPER
    chmod +x $out/bin/pixelstreaming-signaller
  '';

  meta = {
    description = "PixelStreaming WebRTC signalling server and web player";
    homepage = "https://github.com/EpicGamesExt/PixelStreamingInfrastructure";
    license = lib.licenses.mit;
    mainProgram = "pixelstreaming-signaller";
  };
}
