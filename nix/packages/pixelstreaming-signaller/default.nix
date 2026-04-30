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
in
buildNpmPackage {
  pname = "pixelstreaming-signaller";
  inherit version src;

  sourceRoot = "source";
  postPatch = ''
    cp ${./workspace-package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';
  npmDepsHash = "sha256-4cGvYciguQjWn8Jz5FtKcIDWp7eW2JL+pPTBoKux2v8=";

  buildPhase = ''
    runHook preBuild
    cd Common && npm run build:cjs && cd ..
    cd Signalling && npm run build:cjs && cd ..
    cd SignallingWebServer && npm run build && cd ..
    cd Frontend/library && npm run build:cjs && cd ../..
    cd Frontend/ui-library && npm run build:cjs && cd ../..
    cd Frontend/implementations/typescript && npx webpack --config webpack.prod.js && cd ../../..
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,lib/SignallingWebServer,www}

    cp -r Common Signalling SignallingWebServer Frontend node_modules package.json $out/lib/
    cp -r Frontend/implementations/typescript/dist/* $out/www/

    cat > $out/bin/pixelstreaming-signaller <<WRAPPER
    #!${stdenv.shell}
    exec ${nodejs}/bin/node $out/lib/SignallingWebServer/dist/index.js "\$@"
    WRAPPER
    chmod +x $out/bin/pixelstreaming-signaller
    runHook postInstall
  '';

  meta = {
    description = "PixelStreaming WebRTC signalling server and web player";
    homepage = "https://github.com/EpicGamesExt/PixelStreamingInfrastructure";
    license = lib.licenses.mit;
    mainProgram = "pixelstreaming-signaller";
  };
}
