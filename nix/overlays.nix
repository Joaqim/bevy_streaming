let
  sources = import ../npins;
  rust-overlay = import sources.rust-overlay;
in
[
  rust-overlay
  (final: _prev: {
    pixelstreaming-signaller = final.callPackage ./packages/pixelstreaming-signaller { };
  })
]
