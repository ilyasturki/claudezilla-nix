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
  version = "0.6.5";

  src = fetchFromGitHub {
    owner = "boot-industries";
    repo = "claudezilla";
    rev = "33762d3cda85865a869ecdca9912122aa7bd7e18";
    hash = "sha256-B0C3Wef4v7s82btMGJc6LK/OrHmkVDRHE+u/iBwSRMM=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    sourceRoot = "${finalAttrs.src.name}/mcp";
    hash = "sha256-gADsv7csWCNzr1J7rlHGDcRR97M3jJ9npIUTtm+2n3U=";
    fetcherVersion = 2;
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
