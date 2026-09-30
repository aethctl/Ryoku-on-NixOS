{
  pkgs,
  ryotunesUnwrapped,
  ryokuQml,
}:

let
  qmlImports = pkgs.lib.makeSearchPath "lib/qt-6/qml" [
    ryokuQml
    pkgs.qt6.qtdeclarative
    pkgs.qt6.qtmultimedia
    pkgs.qt6.qtwayland
    pkgs.qt6.qt5compat
    pkgs.qt6.qtsvg
    pkgs.qt6.qtimageformats
    pkgs.kdePackages.kirigami.unwrapped
  ];
in
pkgs.symlinkJoin {
  name = "ryoku-ryotunes-${ryotunesUnwrapped.version}";

  paths = [ ryotunesUnwrapped ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postBuild = ''
    makeWrapper ${pkgs.quickshell}/bin/qs "$out/bin/ryotunes-qml" \
      --add-flags "-p ${ryotunesUnwrapped}/share/ryotunes/client" \
      --prefix QML_IMPORT_PATH : "${qmlImports}" \
      --prefix QML2_IMPORT_PATH : "${qmlImports}"
  '';

  meta = ryotunesUnwrapped.meta // {
    description = "Ryotunes with Ryoku desktop integration";
  };
}
