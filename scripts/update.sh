#!/usr/bin/env bash
# Bump claudezilla native host (rev, hash, version, pnpm deps) and the
# AMO Firefox extension (version, sha256). Idempotent — safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

UPSTREAM_REPO="boot-industries/claudezilla"
ADDON_SLUG="claudezilla"
PKG=package.nix
EXT=extension.nix
ZERO_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

bump_host() {
  echo "==> Bumping native host"
  local new_rev new_version
  new_rev=$(git ls-remote "https://github.com/${UPSTREAM_REPO}.git" HEAD | awk '{print $1}')
  new_version=$(curl -fsSL "https://raw.githubusercontent.com/${UPSTREAM_REPO}/${new_rev}/package.json" \
    | grep -oP '"version"\s*:\s*"\K[^"]+' | head -n1)
  echo "    rev:     ${new_rev}"
  echo "    version: ${new_version}"

  local new_src_hash
  new_src_hash=$(nix-prefetch-git --quiet --url "https://github.com/${UPSTREAM_REPO}.git" --rev "${new_rev}" \
    | grep -oP '"hash"\s*:\s*"\K[^"]+')
  echo "    src hash: ${new_src_hash}"

  sed -i \
    -e "s|version = \"[^\"]*\";|version = \"${new_version}\";|" \
    -e "s|rev = \"[^\"]*\";|rev = \"${new_rev}\";|" \
    "${PKG}"

  # Replace the FIRST hash occurrence (the src hash) only.
  awk -v new="${new_src_hash}" '
    !done && /hash = "/ { sub(/hash = "[^"]*"/, "hash = \"" new "\""); done=1 }
    { print }
  ' "${PKG}" > "${PKG}.tmp" && mv "${PKG}.tmp" "${PKG}"

  # Force pnpm deps hash recompute by zeroing it, then capturing the correct one.
  sed -i "0,/hash = \"sha256-[^\"]*\";/{n;s|hash = \"sha256-[^\"]*\";|hash = \"${ZERO_HASH}\";|}" "${PKG}" || true
  # Simpler approach: replace the second hash (pnpmDeps).
  awk -v zero="${ZERO_HASH}" '
    /hash = "/ { count++; if (count == 2) { sub(/hash = "[^"]*"/, "hash = \"" zero "\""); } }
    { print }
  ' "${PKG}" > "${PKG}.tmp" && mv "${PKG}.tmp" "${PKG}"

  echo "==> Building to capture pnpm deps hash"
  local build_log
  build_log=$(nix build .#default 2>&1 || true)
  local correct_pnpm_hash
  correct_pnpm_hash=$(echo "${build_log}" | grep -oE 'sha256-[A-Za-z0-9+/=]{43,}' | tail -n1 || true)
  if [[ -n "${correct_pnpm_hash}" && "${correct_pnpm_hash}" != "${ZERO_HASH}" ]]; then
    echo "    pnpm hash: ${correct_pnpm_hash}"
    awk -v new="${correct_pnpm_hash}" '
      /hash = "/ { count++; if (count == 2) { sub(/hash = "[^"]*"/, "hash = \"" new "\""); } }
      { print }
    ' "${PKG}" > "${PKG}.tmp" && mv "${PKG}.tmp" "${PKG}"
    nix build .#default
  else
    echo "    pnpm hash unchanged or build succeeded as-is"
  fi
}

bump_extension() {
  echo "==> Bumping Firefox extension"
  local meta latest_version xpi_url
  meta=$(curl -fsSL "https://addons.mozilla.org/api/v5/addons/addon/${ADDON_SLUG}/versions/?lang=en-US")
  latest_version=$(echo "${meta}" | grep -oP '"version"\s*:\s*"\K[^"]+' | head -n1)
  xpi_url=$(echo "${meta}" | grep -oP '"url"\s*:\s*"\K[^"]+\.xpi' | head -n1)
  echo "    version: ${latest_version}"
  echo "    xpi url: ${xpi_url}"

  local new_xpi_hash
  new_xpi_hash="sha256-$(nix hash convert --to sri --hash-algo sha256 \
    "$(nix-prefetch-url --type sha256 "${xpi_url}")" 2>/dev/null \
    | sed 's|^sha256-||')"
  # Fallback for older nix: nix-prefetch-url returns base32; convert manually.
  if [[ "${new_xpi_hash}" == "sha256-" ]]; then
    new_xpi_hash="sha256-$(nix-hash --to-base64 --type sha256 \
      "$(nix-prefetch-url --type sha256 "${xpi_url}")")"
  fi
  echo "    xpi hash: ${new_xpi_hash}"

  sed -i \
    -e "s|version = \"[^\"]*\";|version = \"${latest_version}\";|" \
    -e "s|hash = \"sha256-[^\"]*\";|hash = \"${new_xpi_hash}\";|" \
    "${EXT}"

  # Update the xpi download URL (file id may change).
  sed -i -E "s|file/[0-9]+/claudezilla-[^\"]+\\.xpi|$(echo "${xpi_url}" | sed -E 's|.*/(file/[0-9]+/claudezilla-[^"]+\.xpi)|\1|')|" "${EXT}"

  nix build .#firefox-extension
}

bump_host
bump_extension

echo "==> Done"
