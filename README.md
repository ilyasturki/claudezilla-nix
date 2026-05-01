# claudezilla-nix

Nix flake for [Claudezilla](https://github.com/boot-industries/claudezilla) — the Firefox-native browser automation MCP server for Claude Code.

Packages both the native messaging host (`claudezilla-host`, `claudezilla-mcp`) and the AMO-signed Firefox extension as separate derivations.

## Why this flake?

Claudezilla is not in nixpkgs. This flake gives you:

- A reproducible install pinned to an exact upstream commit + AMO extension version.
- An automated weekly update PR that bumps both the host rev and the extension xpi.
- A clean integration point for home-manager (Firefox extension package + native messaging manifest).

## Quick start

Run the MCP server directly without installing:

```sh
nix run github:ilyasturki/claudezilla-nix
```

## Standalone installation

```sh
nix profile install github:ilyasturki/claudezilla-nix
claudezilla-mcp --help
```

To uninstall: `nix profile remove claudezilla`.

## Using with Nix flakes

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claudezilla-nix.url = "github:ilyasturki/claudezilla-nix";
  };

  outputs = { nixpkgs, claudezilla-nix, ... }: {
    # ... use claudezilla-nix.packages.${system}.default
    #     and claudezilla-nix.packages.${system}.firefox-extension
  };
}
```

You can also consume the overlay:

```nix
nixpkgs.overlays = [ claudezilla-nix.overlays.default ];
# pkgs.claudezilla and pkgs.claudezilla-firefox-extension become available
```

## Using with home-manager

Wire the Firefox extension, the native messaging host manifest, and the Claude Code MCP server in a single home-manager module:

```nix
{ pkgs, inputs, ... }:
let
  cz = inputs.claudezilla-nix.packages.${pkgs.system}.default;
  ext = inputs.claudezilla-nix.packages.${pkgs.system}.firefox-extension;
in
{
  home.packages = [ cz ];

  home.file.".mozilla/native-messaging-hosts/claudezilla.json".source =
    (pkgs.formats.json { }).generate "claudezilla-native-host.json" {
      name = "claudezilla";
      description = "Claude Code Firefox browser automation bridge";
      path = "${cz}/bin/claudezilla-host";
      type = "stdio";
      allowed_extensions = [ ext.addonId ];
    };

  programs.firefox.profiles.default.extensions.packages = [ ext ];
}
```

After rebuild, open `about:addons` in Firefox once to confirm the extension is enabled.

## Updating

The flake input is pinned via `flake.lock`. Bump it with:

```sh
nix flake update
```

The repo itself is auto-updated weekly via `.github/workflows/update.yml`, which opens a PR bumping the host rev/hash and the AMO extension version/hash.

To run the update locally:

```sh
./scripts/update.sh
```

## Development

```sh
nix develop                 # shell with nixpkgs-fmt and nix-prefetch-git
nix build .#default         # builds the native host
nix build .#firefox-extension
nix flake check
```

## License

MIT. Upstream Claudezilla is also MIT — see [boot-industries/claudezilla](https://github.com/boot-industries/claudezilla).
