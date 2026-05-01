{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "claudezilla-firefox-extension";
  version = "0.6.4";

  src = fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/4747442/claudezilla-${finalAttrs.version}.xpi";
    hash = "sha256-nDYNE2iWrjHWSrUmifm8GJeI0YC1nJ6jkD1TncH6nuM=";
  };

  preferLocalBuild = true;
  allowSubstitutes = true;

  dontUnpack = true;

  passthru = {
    addonId = "claudezilla@boot.industries";
  };

  installPhase = ''
    runHook preInstall

    dst=$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}
    mkdir -p "$dst"
    install -m644 "$src" "$dst/${finalAttrs.passthru.addonId}.xpi"

    runHook postInstall
  '';

  meta = {
    description = "Claudezilla Firefox extension (AMO-signed) for Claude Code browser automation";
    homepage = "https://addons.mozilla.org/en-US/firefox/addon/claudezilla/";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mozPermissions = [
      "nativeMessaging"
      "tabs"
      "activeTab"
      "<all_urls>"
      "webRequest"
      "webRequestBlocking"
      "storage"
    ];
  };
})
