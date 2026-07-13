{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  pnpm_10,
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
    hash = "sha256-+kVkbACg+HKkZF5F+6WOibhVKb1ZPDbNyOUf/OhaqN8=";
    fetcherVersion = 3;
    pnpm = pnpm_10;
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm_10
    pnpmConfigHook
  ];

  pnpmRoot = "mcp";

  dontBuild = true;

  installPhase =
    let
      # Shipped in-package at the wrapFirefox / MOZ_SYSTEM_DIR location so
      # consumers register it via programs.firefox.nativeMessagingHosts rather
      # than hand-writing a manifest into ~/.mozilla. allowed_extensions mirrors
      # claudezilla-firefox-extension's passthru.addonId.
      nativeHostManifest = builtins.toJSON {
        name = "claudezilla";
        description = "Claude Code Firefox browser automation bridge";
        path = "${placeholder "out"}/bin/claudezilla-host";
        type = "stdio";
        allowed_extensions = [ "claudezilla@boot.industries" ];
      };
    in
    ''
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

      mkdir -p $out/lib/mozilla/native-messaging-hosts
      printf '%s\n' ${lib.escapeShellArg nativeHostManifest} \
        > $out/lib/mozilla/native-messaging-hosts/claudezilla.json

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
