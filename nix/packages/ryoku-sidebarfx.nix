{ pkgs, src, qmlRoot }:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-sidebarfx";
  version = "unstable";

  dontWrapQtApps = true;

  src = src + "/ryoku/shell/sidebarfx";

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.qt6.qtshadertools
  ];

  buildInputs = [
    pkgs.qt6.qtbase
    pkgs.qt6.qtdeclarative
    pkgs.qt6.qtshadertools
  ];

  preConfigure = ''
    rm -rf build
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/${qmlRoot}/Ryoku"

    cp -a \
      qml/Ryoku/SidebarFx \
      "$out/${qmlRoot}/Ryoku/SidebarFx"

    rm -f "$out/${qmlRoot}/Ryoku/SidebarFx/"*.qrc

    runHook postInstall
  '';

  meta = {
    description = "Ryoku.SidebarFx native sidebar depth rendering module";
    homepage = "https://github.com/Ryoku-dev/ryoku";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
