{
  pkgs,
  src,
  provider,
}:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-wm-${provider}";
  version = "unstable";

  inherit src;

  nativeBuildInputs = [ pkgs.go ];

  buildPhase = ''
    runHook preBuild

    export CGO_ENABLED=0
    export GOCACHE="$TMPDIR/go-cache"
    export GOTOOLCHAIN=local
    export HOME="$TMPDIR/home"

    mkdir -p ryoku/wm/vendor/github.com/BurntSushi
    cp -a \
      ryoku/hub/backend/vendor/github.com/BurntSushi/toml \
      ryoku/wm/vendor/github.com/BurntSushi/toml
    printf '%s\n' \
      '# github.com/BurntSushi/toml v1.6.0' \
      '## explicit; go 1.18' \
      'github.com/BurntSushi/toml' \
      'github.com/BurntSushi/toml/internal' \
      > ryoku/wm/vendor/modules.txt

    (
      cd ryoku/wm
      go build -mod=vendor -trimpath \
        -o "$TMPDIR/ryoku-wm-${provider}" \
        "./${provider}"
    )

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 \
      "$TMPDIR/ryoku-wm-${provider}" \
      "$out/bin/ryoku-wm-${provider}"

    runHook postInstall
  '';

  meta = {
    description = "Ryoku ${provider} window-manager provider";
    homepage = "https://github.com/Ryoku-dev/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ryoku-wm-${provider}";
  };
}
