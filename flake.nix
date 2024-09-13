{
  outputs = inputs @ {...}: let
    system = "x86_64-linux";
    pkgs = import <nixpkgs> {};
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        (pkgs.writeScriptBin "publish" ''
          #!${pkgs.bash}/bin/bash

          set -ue -o pipefail

          function git() {
            ${pkgs.gitMinimal}/bin/git "$@"
          }
          function main() {
            local target="$1"
            local worktree="$(${pkgs.coreutils}/bin/mktemp --directory --dry-run)"

            git worktree add --orphan -b "$target" "$worktree"

            ${pkgs.rsync}/bin/rsync --recursive --del --checksum --exclude=".git" "./$target/" "$worktree/"
            cd "$worktree"

            if ! git log -0 > /dev/null 2>&1; then
              git commit --allow-empty -m "initial commit"
            fi

            git add .
            git commit -m publish
            git push || true

            cd -
            git worktree remove "$worktree"
          }
          main "$@"
        '')
      ];
    };
  };
}
