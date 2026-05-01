{
  description = "Claudezilla — Firefox browser automation MCP for Claude Code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      overlay = final: _prev: {
        claudezilla = final.callPackage ./package.nix { };
        claudezilla-firefox-extension = final.callPackage ./extension.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.claudezilla;
          inherit (pkgs) claudezilla;
          firefox-extension = pkgs.claudezilla-firefox-extension;
        };

        apps.default = {
          type = "app";
          program = "${pkgs.claudezilla}/bin/claudezilla-mcp";
          meta = {
            description = "Claudezilla MCP server for Claude Code";
            license = pkgs.lib.licenses.mit;
            mainProgram = "claudezilla-mcp";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch-git
          ];
        };

        formatter = pkgs.nixfmt;
      }
    )
    // {
      overlays.default = overlay;
    };
}
