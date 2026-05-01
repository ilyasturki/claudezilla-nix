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

# Always invoke nixpkgs' tools rather than whatever happens to be on PATH
# (e.g. hydra's nix-prefetch-git, which has incompatible flags).
NIX_PREFETCH_GIT=(nix run --extra-experimental-features 'nix-command flakes' nixpkgs#nix-prefetch-git --)
JQ=(nix run --extra-experimental-features 'nix-command flakes' nixpkgs#jq --)

# Replace the Nth `hash = "sha256-..."` occurrence in $1 with $3.
replace_hash() {
  local file=$1 nth=$2 new_hash=$3
  awk -v n="$nth" -v new="$new_hash" '
    /hash = "sha256-/ {
      count++
      if (count == n) {
        sub(/hash = "sha256-[^"]*"/, "hash = \"" new "\"")
      }
    }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

bump_host() {
  echo "==> Bumping native host"
  local new_rev new_version new_src_hash
  new_rev=$(git ls-remote "https://github.com/${UPSTREAM_REPO}.git" HEAD | awk '{print $1}')
  new_version=$(curl -fsSL "https://raw.githubusercontent.com/${UPSTREAM_REPO}/${new_rev}/package.json" \
    | "${JQ[@]}" -r .version)
  echo "    rev:     ${new_rev}"
  echo "    version: ${new_version}"

  new_src_hash=$("${NIX_PREFETCH_GIT[@]}" --quiet --url "https://github.com/${UPSTREAM_REPO}.git" --rev "${new_rev}" \
    | "${JQ[@]}" -r .hash)
  echo "    src hash: ${new_src_hash}"

  sed -i \
    -e "s|version = \"[^\"]*\";|version = \"${new_version}\";|" \
    -e "s|rev = \"[^\"]*\";|rev = \"${new_rev}\";|" \
    "${PKG}"

  # Hash 1 = src, 2 = pnpmDeps. Zero pnpmDeps so the build will tell us the right one.
  replace_hash "${PKG}" 1 "${new_src_hash}"
  replace_hash "${PKG}" 2 "${ZERO_HASH}"

  echo "==> Building to capture pnpm deps hash"
  local build_log
  if build_log=$(nix build .#default 2>&1); then
    echo "    build succeeded with zero hash (pnpm deps unchanged)"
    return
  fi

  if ! grep -q 'hash mismatch in fixed-output derivation' <<< "${build_log}"; then
    echo "==> Build failed for non-hash reason:" >&2
    printf '%s\n' "${build_log}" >&2
    exit 1
  fi

  local correct_pnpm_hash
  correct_pnpm_hash=$(grep -oE 'got:[[:space:]]*sha256-[A-Za-z0-9+/=]+' <<< "${build_log}" \
    | grep -oE 'sha256-[A-Za-z0-9+/=]+' | head -n1) || true
  if [[ -z "${correct_pnpm_hash}" ]]; then
    echo "==> Could not parse pnpm hash from build log:" >&2
    printf '%s\n' "${build_log}" >&2
    exit 1
  fi
  echo "    pnpm hash: ${correct_pnpm_hash}"
  replace_hash "${PKG}" 2 "${correct_pnpm_hash}"
  nix build .#default
}

bump_extension() {
  echo "==> Bumping Firefox extension"
  local meta latest_version xpi_url new_xpi_hash new_file_id
  meta=$(curl -fsSL "https://addons.mozilla.org/api/v5/addons/addon/${ADDON_SLUG}/versions/?lang=en-US")
  latest_version=$("${JQ[@]}" -r '.results[0].version // empty' <<< "${meta}")
  xpi_url=$("${JQ[@]}" -r '.results[0].file.url // .results[0].files[0].url // empty' <<< "${meta}")
  if [[ -z "${latest_version}" || -z "${xpi_url}" ]]; then
    echo "==> AMO API returned an unexpected shape:" >&2
    printf '%s\n' "${meta}" >&2
    exit 1
  fi
  echo "    version: ${latest_version}"
  echo "    xpi url: ${xpi_url}"

  new_xpi_hash=$(nix hash to-sri --type sha256 "$(nix-prefetch-url --type sha256 "${xpi_url}")")
  echo "    xpi hash: ${new_xpi_hash}"

  sed -i \
    -e "s|version = \"[^\"]*\";|version = \"${latest_version}\";|" \
    -e "s|hash = \"sha256-[^\"]*\";|hash = \"${new_xpi_hash}\";|" \
    "${EXT}"

  # Replace only the numeric file id so the ${finalAttrs.version} interpolation is preserved.
  new_file_id=$(sed -nE 's|.*/file/([0-9]+)/.*|\1|p' <<< "${xpi_url}")
  if [[ -z "${new_file_id}" ]]; then
    echo "==> Could not parse file id from xpi URL: ${xpi_url}" >&2
    exit 1
  fi
  sed -i -E "s|file/[0-9]+/claudezilla-|file/${new_file_id}/claudezilla-|" "${EXT}"

  nix build .#firefox-extension
}

verify() {
  echo "==> Validating updated flake"
  nix flake check
}

bump_host
bump_extension
verify

echo "==> Done"
