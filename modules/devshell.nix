{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    nix
    alejandra
    # void-editor is available via overlays, do not duplicate
  ];
}
