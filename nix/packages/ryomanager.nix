{
  pkgs,
  ryomanagerSrc,
}:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "ryomanager";
  version = "0.1.0";

  src = ryomanagerSrc;

  cargoRoot = "src-tauri";
  cargoHash = "sha256-PFuifNsW7KC8wd6ecUK3MJMKrV9DEKloJkF17U94s9M=";

  npmDeps = pkgs.fetchNpmDeps {
    inherit src;
    hash = "sha256-AVtSOV1bUS1aiSqajdSqfM6/Y9SWc8rdBMpH9y18aFc=";
  };

  nativeBuildInputs = [
    pkgs.nodejs
    pkgs.npmHooks.npmConfigHook
    pkgs.pkg-config
    pkgs.wrapGAppsHook3
  ];

  buildInputs = [
    pkgs.glib
    pkgs.gtk3
    pkgs.gdk-pixbuf
    pkgs.cairo
    pkgs.pango
    pkgs.libsoup_3
    pkgs.webkitgtk_4_1
    pkgs.openssl
  ];

  preBuild = ''
    export HOME="$TMPDIR"
    npm run build
    test -f dist/index.html
  '';

  cargoBuildFlags = [
    "--manifest-path"
    "src-tauri/Cargo.toml"
  ];

  # The upstream crate currently has no Rust tests. The source repository is
  # checked separately; avoid linking the full Tauri binary a second time in
  # the Nix build just to execute an empty test suite.
  doCheck = false;

  installPhase = ''
    runHook preInstall

    install -Dm755 \
      src-tauri/target/${pkgs.stdenv.hostPlatform.rust.rustcTarget}/release/ryomanager \
      "$out/bin/ryomanager" 2>/dev/null || \
    install -Dm755 \
      src-tauri/target/release/ryomanager \
      "$out/bin/ryomanager"

    install -Dm644 \
      src-tauri/icons/icon.png \
      "$out/share/icons/hicolor/512x512/apps/ryomanager.png"

    install -Dm644 /dev/stdin "$out/share/applications/ryomanager.desktop" <<'DESKTOP'
[Desktop Entry]
Name=RyoManager
Comment=Ryoku system task manager
Exec=ryomanager
Icon=ryomanager
Terminal=false
Type=Application
Categories=System;Monitor;
StartupWMClass=ryomanager
DESKTOP

    runHook postInstall
  '';

  meta = {
    description = "Ryoku-native system task manager";
    homepage = "https://github.com/aethctl/ryomanager";
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ryomanager";
  };
}
