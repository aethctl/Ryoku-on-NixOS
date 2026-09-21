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

    # Upstream now commits ryoku/wm/vendor, so the provider is fully
    # offline-buildable from its own source tree. Do not synthesize another
    # vendor tree from the Hub copy here.

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
