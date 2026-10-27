#!/usr/bin/env bash
# Needs nix-update and jq: run it through `nix develop --command`.
set -euo pipefail

cd "$(dirname "$0")/.."

nix-update --flake claudezilla

amo=$(curl -fsSL https://addons.mozilla.org/api/v5/addons/addon/claudezilla/versions/)
version=$(jq -r '.results[0].version' <<< "${amo}")
file_id=$(jq -r '.results[0].file.id' <<< "${amo}")
hash=$(nix hash convert --hash-algo sha256 --to sri \
  "$(jq -r '.results[0].file.hash | ltrimstr("sha256:")' <<< "${amo}")")

sed -i -E \
  -e "s|version = \"[^\"]*\";|version = \"${version}\";|" \
  -e "s|file/[0-9]+/|file/${file_id}/|" \
  -e "s|hash = \"sha256-[^\"]*\";|hash = \"${hash}\";|" \
  extension.nix

nix build .#claudezilla .#firefox-extension
nix flake check
