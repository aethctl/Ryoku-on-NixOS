{
  pkgs,
  src,
  livewall,
  waifu2x,
}:

let
  waifu2xModels =
    "${waifu2x}/share/waifu2x-ncnn-vulkan/models-cunet";

  runtimePath = pkgs.lib.makeBinPath [
    pkgs.coreutils
    pkgs.procps

    pkgs.ffmpeg
    pkgs.imagemagick
    pkgs.matugen

    pkgs.curl
    pkgs.inotify-tools

    pkgs.quickshell

    waifu2x
  ];
in

pkgs.stdenv.mkDerivation {
  pname = "ryoku-ryogami";
  version = "unstable";

  src = src + "/ryoku/shell/ryogami";

  nativeBuildInputs = [
    pkgs.go
    pkgs.makeWrapper
  ];

  postPatch = ''
    # Upstream packages waifu2x models below /usr/share. On NixOS
    # they live inside Ryoku's immutable waifu2x derivation.
    substituteInPlace daemon/upscale.go \
      --replace-fail \
        '/usr/share/waifu2x-ncnn-vulkan/models-cunet' \
        '${waifu2xModels}'

    # NixOS exposes the active OpenGL/VAAPI driver set through
    # /run/opengl-driver rather than Arch's /usr/lib/dri.
    substituteInPlace daemon/livewall.go \
      --replace-fail \
        '/usr/lib/dri/radeonsi_drv_video.so' \
        '/run/opengl-driver/lib/dri/radeonsi_drv_video.so'
  '';

  buildPhase = ''
    runHook preBuild

    root="$PWD"

    cd daemon

    export HOME="$TMPDIR"
    export GOCACHE="$TMPDIR/go-cache"
    export GOTOOLCHAIN=local
    export CGO_ENABLED=0

    go test ./...

    go build \
      -trimpath \
      -o ryogami \
      .

    cd "$root"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/bin" \
      "$out/share/ryogami" \
      "$out/share/applications"

    install -Dm755 \
      daemon/ryogami \
      "$out/bin/ryogami"

    # Ryogami expects this executable name. Reuse the existing
    # Nix-built lightweight renderer rather than rebuilding it.
    ln -s \
      "${livewall}/bin/ryoku-livewall" \
      "$out/bin/ryogami-live"

    # Vendored Ryogami wallpaper picker.
    cp -a \
      wall-ui/. \
      "$out/share/ryogami/"

    install -Dm644 \
      wall-ui/data/ryogami-wall.desktop \
      "$out/share/applications/ryogami-wall.desktop"

    # Make the package self-contained outside the full Ryoku
    # systemd service as well.
    wrapProgram "$out/bin/ryogami" \
      --set RYOGAMI_SHELL_QML "$out/share/ryogami/shell.qml" \
      --prefix PATH : "$out/bin:${runtimePath}"

    runHook postInstall
  '';

  meta = {
    description =
      "Ryogami wallpaper daemon and wallpaper picker for Ryoku";
    homepage =
      "https://github.com/ryoku-dev/ryoku-arch";
    license = pkgs.lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
