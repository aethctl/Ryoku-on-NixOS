{ pkgs, src }:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-hub";
  version = "unstable";

  src = src + "/ryoku/hub/backend";

  nativeBuildInputs = [
    pkgs.go
    pkgs.makeWrapper
  ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"
    export GOCACHE="$TMPDIR/go-cache"
    export GOTOOLCHAIN=local

    go build \
      -mod=vendor \
      -trimpath \
      -o ryoku-hub \
      .

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec"

    install -Dm755 \
      ryoku-hub \
      "$out/libexec/ryoku-hub"

    makeWrapper \
      "$out/libexec/ryoku-hub" \
      "$out/bin/ryoku-hub" \
      --set RYOKU_XKB_RULES_DIR "${pkgs.xkeyboard_config}/share/X11/xkb/rules" \
      --set XKB_CONFIG_ROOT "${pkgs.xkeyboard_config}/share/X11/xkb"

    runHook postInstall
  '';

  meta = {
    description = "Ryoku Settings and Hub backend";
    homepage = "https://github.com/Ryoku-dev/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
