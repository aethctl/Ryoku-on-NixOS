{ pkgs }:

pkgs.buildGoModule {
  pname = "prowl-agent";
  version = "0.15.6";

  src =
    pkgs.fetchFromGitHub {
      owner = "neur0map";
      repo = "prowl-agent";
      rev = "506e54fb7b049ceea556255205f8acd3ee20ac9e";
      hash = "sha256-PDEyYPiWYRjwmFwAg9BswhmdTmItYIEC5DxhDJYTznY=";
    };

  vendorHash = "sha256-kacn0Xevq6l6fxVtO2A527vxnH0y9fFDo6qYQRA6XMs=";

  # sqlite-vec includes <sqlite3.h> during CGO compilation.
  #
  # Prowl's go-sqlite3 dependency still builds its own bundled SQLite
  # amalgamation, so this is header availability only — we deliberately
  # do not link Prowl against Nixpkgs' libsqlite3.
  buildInputs = [
    pkgs.sqlite
  ];

  # Prowl uses SQLite FTS5 through CGO. buildGoModule enables
  # CGO by default on this platform; do not duplicate CGO_ENABLED
  # as a top-level derivation attribute.
  tags = [
    "sqlite_fts5"
  ];

  subPackages = [
    "cmd/prowl-agent"
  ];

  # Immutable Nix builds must never self-update into the store.
  ldflags = [
    "-s"
    "-w"
    "-X main.version=v0.15.6"
    "-X main.managedBy=nix"
  ];

  meta = {
    description =
      "Local code-intelligence indexer and MCP server used by Ryoku Rashin";

    homepage =
      "https://github.com/neur0map/prowl-agent";

    mainProgram =
      "prowl-agent";

    platforms =
      pkgs.lib.platforms.linux;
  };
}
