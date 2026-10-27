{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  fetchPnpmDeps,
  nix-update-script,
}:
let
  lockfilePatch = ./patches/0002-refresh-mcp-lockfile-for-sdk-1.32.1.patch;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "claudezilla";
  version = "0.7.2";

  src = fetchFromGitHub {
    owner = "boot-industries";
    repo = "claudezilla";
    tag = "v${finalAttrs.version}";
    hash = "sha256-N9aBahjzCHi3SoFXSViAG/vsST8eWim8OsCg8u7rg/Q=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    sourceRoot = "${finalAttrs.src.name}/mcp";
    patches = [ lockfilePatch ];
    # The patch is rooted at the repository, one level above sourceRoot.
    patchFlags = [ "-p2" ];
    hash = "sha256-gOCkp1mXnScHl6R+06B5zXRP/G2+9tIFUK1wPGVX0Ms=";
    fetcherVersion = 3;
    pnpm = pnpm_10;
  };

  patches = [
    lockfilePatch
    ./patches/0001-keep-gateway-tool-listed-after-activation.patch
  ];

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

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Firefox browser automation bridge for Claude Code (native host + MCP server)";
    homepage = "https://claudezilla.com";
    changelog = "https://github.com/boot-industries/claudezilla/blob/v${finalAttrs.version}/CHANGELOG.md";
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
