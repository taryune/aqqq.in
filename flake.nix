{
  description = "Hugo development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      let
        site = pkgs.stdenv.mkDerivation {
          pname = "clue-spot";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = with pkgs; [
            hugo
            dart-sass
            go
          ];

          buildPhase = ''
            runHook preBuild
            hugo --gc --minify --logLevel info
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r public/. $out/
            runHook postInstall
          '';
        };

        deploy = pkgs.writeShellApplication {
          name = "clue-spot-deploy";
          runtimeInputs = [ pkgs.wrangler ];
          text = ''
            set -euo pipefail

            branch="''${1:-main}"
            workdir="$(mktemp -d)"
            trap 'rm -rf "$workdir"' EXIT

            echo "Staging built site from ${site} ..."
            mkdir -p "$workdir/public"
            cp -rL ${site}/. "$workdir/public/"
            chmod -R u+w "$workdir/public"

            echo "Deploying to Cloudflare Pages (branch: $branch) ..."
            wrangler pages deploy "$workdir/public" \
              --project-name=clue-spot \
              --branch="$branch"
          '';
        };

        deploy-ci = pkgs.writeShellApplication {
          name = "clue-spot-deploy-ci";
          runtimeInputs = [ pkgs.wrangler ];
          text = ''
            set -euo pipefail

            : "''${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
            : "''${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}"

            # GitHub Actions provides:
            #   GITHUB_HEAD_REF - source branch on pull_request events (empty otherwise)
            #   GITHUB_REF_NAME - short ref name on push events
            # Prefer head ref so PR previews deploy under the PR branch name.
            branch="''${GITHUB_HEAD_REF:-''${GITHUB_REF_NAME:-main}}"

            workdir="$(mktemp -d)"
            trap 'rm -rf "$workdir"' EXIT

            echo "Staging built site from ${site} ..."
            mkdir -p "$workdir/public"
            cp -rL ${site}/. "$workdir/public/"
            chmod -R u+w "$workdir/public"

            echo "Deploying to Cloudflare Pages (branch: $branch) ..."
            wrangler pages deploy "$workdir/public" \
              --project-name=clue-spot \
              --branch="$branch"
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            hugo
            go
            dart-sass
            git
            wrangler
          ];

          shellHook = ''
            echo "Hugo $(hugo version)"
          '';
        };

        packages.default = site;
        packages.deploy = deploy;
        packages.deploy-ci = deploy-ci;

        apps.deploy = {
          type = "app";
          program = "${deploy}/bin/clue-spot-deploy";
        };

        apps.deploy-ci = {
          type = "app";
          program = "${deploy-ci}/bin/clue-spot-deploy-ci";
        };
      });
}
