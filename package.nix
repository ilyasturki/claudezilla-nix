{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  pnpm_9,
  pnpmConfigHook,
  fetchPnpmDeps,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "claudezilla";
  version = "0.6.6";

  src = fetchFromGitHub {
    owner = "boot-industries";
    repo = "claudezilla";
    rev = "34368f7a697b19f40c70be4aee4bde8f738670a0";
    hash = "sha256-2ULHI2qQcSmrABVGh5/40+TntXJDUAjQjlaDCLNNWuM=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    sourceRoot = "${finalAttrs.src.name}/mcp";
    hash = "sha256-6jHicbKxh2mZLUuwzgYgI+EJc9sunF+916EQ/bbv+EQ=";
    fetcherVersion = 3;
    pnpm = pnpm_9;
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm_9
    pnpmConfigHook
  ];

  pnpmRoot = "mcp";

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    libexec=$out/libexec/claudezilla
    mkdir -p $libexec $out/bin

    cp -r host $libexec/host
    cp -r mcp $libexec/mcp

    chmod 755 $libexec/host/index.js
    chmod 755 $libexec/mcp/server.js

    makeWrapper ${nodejs}/bin/node $out/bin/claudezilla-host \
      --add-flags "$libexec/host/index.js"

    makeWrapper ${nodejs}/bin/node $out/bin/claudezilla-mcp \
      --add-flags "$libexec/mcp/server.js"

    runHook postInstall
  '';

  meta = {
    description = "Firefox browser automation bridge for Claude Code (native host + MCP server)";
    homepage = "https://claudezilla.com";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "claudezilla-mcp";
    maintainers = [
      {
        name = "Ilyas Turki";
        github = "ilyasturki";
      }
    ];
  };
})
