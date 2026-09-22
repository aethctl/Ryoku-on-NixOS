{ pkgs }:

pkgs.rustPlatform.buildRustPackage {
  pname = "xwayland-satellite";
  version = "0.8.2.r13.gadd2795";

  src = pkgs.fetchFromGitHub {
    owner = "Supreeeme";
    repo = "xwayland-satellite";
    rev = "add2795134593faafce60e404a0a75df68e9ee0c";
    hash = "sha256-0TxfMgqW0/BLD4M942c5DCKYrtPvzsPJwvdcco4LQUM=";
  };

  cargoHash = "sha256-s1gl9eR6Mt2QLrhfcowstPFjzwE/lz4PJhJzWYHoIHg=";

  outputs = [
    "out"
    "man"
  ];

  nativeBuildInputs = [
    pkgs.installShellFiles
    pkgs.makeBinaryWrapper
    pkgs.pkg-config
    pkgs.rustPlatform.bindgenHook
  ];

  buildInputs = [
    pkgs.libxcb
    pkgs.libxcb-cursor
  ];

  buildNoDefaultFeatures = true;
  buildFeatures = [ "systemd" ];

  doCheck = false;

  postPatch = "substituteInPlace resources/xwayland-satellite.service --replace-fail \"/usr/local/bin\" \"$out/bin\"";

  postInstall = "installManPage --name xwayland-satellite.1 xwayland-satellite.man; install -Dm0644 resources/xwayland-satellite.service -t $out/lib/systemd/user";

  postFixup = "wrapProgram $out/bin/xwayland-satellite --prefix PATH : \"${pkgs.lib.makeBinPath [ pkgs.xwayland ]}\"";

  meta = pkgs.xwayland-satellite.meta // {
    description = "Xwayland satellite with the Niri override-redirect popup-focus fix";
  };
}
