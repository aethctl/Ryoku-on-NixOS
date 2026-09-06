{
  pkgs,
  ryotunesSrc,
}:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "ryoku-ryotunes";
  version = "2.4.1";

  src = ryotunesSrc;

  # Rust dependencies are fully described by upstream's committed
  # Cargo.lock, so we do not need a separate cargoHash.
  cargoLock = {
    lockFile = "${ryotunesSrc}/Cargo.lock";
  };

  # The Svelte/Vite frontend is a standalone pnpm project under ui/.
  #
  # The first build intentionally starts with fakeHash. The script
  # surrounding this derivation captures Nix's real hash and writes
  # it back before doing the final build.
  pnpmDeps = pkgs.fetchPnpmDeps {
    pname = "ryotunes-ui";
    inherit version;

    src = ryotunesSrc + "/ui";

    fetcherVersion = 4;
    hash = "sha256-L0HRYhFO5A0qqwdiYzN+h28kV7vAqB3up+Zu4ShYnBo=";
  };

  pnpmRoot = "ui";

  nativeBuildInputs = [
    pkgs.pkg-config

    pkgs.nodejs
    pkgs.pnpm
    pkgs.pnpmConfigHook

    pkgs.makeWrapper
    pkgs.wrapGAppsHook3

    # libmpv2's sys layer may require bindgen depending on the
    # resolved crate version. Providing the standard hook keeps
    # that path deterministic.
    pkgs.rustPlatform.bindgenHook
  ];

  buildInputs = [
    pkgs.glib
    pkgs.gtk3
    pkgs.gdk-pixbuf
    pkgs.cairo
    pkgs.pango

    pkgs.webkitgtk_4_1
    pkgs.libsoup_3

    pkgs.mpv

    pkgs.libappindicator-gtk3
    pkgs.libayatana-appindicator

    pkgs.openssl
  ];

  # Upstream performs these as two explicit stages:
  #
  #   ui/ -> pnpm build -> ui/build
  #   cargo build --release --locked --package ryotunes
  #
  # buildRustPackage handles the locked Cargo invocation; this
  # hook produces the frontend Tauri embeds.
  preBuild = ''
    export HOME="$TMPDIR"

    (
      cd ui
      pnpm build
    )

    test -f ui/build/index.html
  '';

  cargoBuildFlags = [
    "--package"
    "ryotunes"
  ];

  # Upstream's release packaging does not run the application test
  # suite as part of packaging. Runtime integration will be tested
  # after Musubi's complete generation is assembled.
  doCheck = false;

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/bin" \
      "$out/share/applications" \
      "$out/share/icons/hicolor/32x32/apps" \
      "$out/share/icons/hicolor/64x64/apps" \
      "$out/share/icons/hicolor/128x128/apps" \
      "$out/share/icons/hicolor/256x256/apps" \
      "$out/share/icons/hicolor/512x512/apps" \
      "$out/share/metainfo" \
      "$out/share/licenses/ryotunes"

    binary="$(
      find target \
        -type f \
        -path '*/release/ryotunes' \
        -perm -0100 \
        -print \
        -quit
    )"

    if [ -z "$binary" ]; then
      printf '%s\n' \
        "ryoku-ryotunes: built ryotunes binary not found" >&2
      exit 1
    fi

    install -Dm755 \
      "$binary" \
      "$out/bin/ryotunes"

    cat > "$out/share/applications/ryotunes.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Ryotunes
GenericName=Music Player
Comment=The Ryoku music app
Exec=ryotunes
Icon=ryotunes
Terminal=false
Categories=AudioVideo;Audio;Player;
Keywords=music;youtube;ytmusic;player;ryotunes;lyrics;
StartupNotify=true
StartupWMClass=ryotunes
DESKTOP

    install -Dm644 \
      packaging/linux/dev.ryoku.ryotunes.metainfo.xml \
      "$out/share/metainfo/dev.ryoku.ryotunes.metainfo.xml"

    install -Dm644 \
      LICENSE \
      "$out/share/licenses/ryotunes/LICENSE"

    install -Dm644 \
      src-tauri/icons/32x32.png \
      "$out/share/icons/hicolor/32x32/apps/ryotunes.png"

    install -Dm644 \
      src-tauri/icons/64x64.png \
      "$out/share/icons/hicolor/64x64/apps/ryotunes.png"

    install -Dm644 \
      src-tauri/icons/128x128.png \
      "$out/share/icons/hicolor/128x128/apps/ryotunes.png"

    install -Dm644 \
      src-tauri/icons/128x128@2x.png \
      "$out/share/icons/hicolor/256x256/apps/ryotunes.png"

    install -Dm644 \
      src-tauri/icons/icon.png \
      "$out/share/icons/hicolor/512x512/apps/ryotunes.png"

    runHook postInstall
  '';

  meta = {
    description =
      "Ryotunes native YouTube Music client for the Ryoku desktop";

    homepage =
      "https://github.com/neur0map/ryotunes";

    license = pkgs.lib.licenses.gpl3Plus;

    platforms = [
      "x86_64-linux"
    ];

    mainProgram = "ryotunes";
  };
}
