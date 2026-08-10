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
  version = "0.6.9";

  src = fetchFromGitHub {
    owner = "boot-industries";
    repo = "claudezilla";
    rev = "167730252d039e05e6b29114b74266d948c40dd4";
    hash = "sha256-I6iLNSm3YQKFlYrF4k6UriwKHTc/1ZHFDCjF07+MStg=";
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
