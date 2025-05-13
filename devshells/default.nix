{ pkgs, devmods ? null, flakelight ? null, ... }:
{
  minimal = if devmods != null && flakelight != null then
    devmods.mkShell {
      name = "minimal-devshell";
      packages = with pkgs; [ git nix alejandra ];
    }
  else
    pkgs.mkShell {
      name = "minimal-devshell";
      buildInputs = with pkgs; [ git nix alejandra ];
    };
  # void-editor devshell is defined in void-editor.nix, do not duplicate
}
