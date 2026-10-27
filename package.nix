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
  version = "0.7.2";

  src = fetchFromGitHub {
    owner = "boot-industries";
    repo = "claudezilla";
    rev = "7823c37c5e77b173c99b4df8e967f02b9d043569";
    hash = "sha256-Pa3YZ5lkkYimwN6a7rKeV83E9OqlV8E861Te8b0Nl4U=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    # Upstream doesn't always refresh its lockfile when bumping deps; scripts/update.sh regenerates it.
    postPatch = "cp ${./mcp-pnpm-lock.yaml} pnpm-lock.yaml";
    sourceRoot = "${finalAttrs.src.name}/mcp";
    hash = "sha256-gOCkp1mXnScHl6R+06B5zXRP/G2+9tIFUK1wPGVX0Ms=";
    fetcherVersion = 3;
    pnpm = pnpm_10;
  };

  patches = [ ./patches/0001-keep-gateway-tool-listed-after-activation.patch ];

  postPatch = "cp ${./mcp-pnpm-lock.yaml} mcp/pnpm-lock.yaml";

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
