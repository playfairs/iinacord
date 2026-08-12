{ pkgs }:

{
  formatter = pkgs.writeShellApplication {
    name = "format";

    runtimeInputs = with pkgs; [
      swift-format
      fd
    ];

    text = ''
      set -euo pipefail

      fd \
        --extension swift \
        --type file \
        . \
      | while read -r file; do
          swift-format \
            --in-place \
            "$file"
        done
    '';
  };
}