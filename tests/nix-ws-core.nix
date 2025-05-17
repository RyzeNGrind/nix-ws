{ pkgs, self', ... }@args:
let
  baseConfig = import ../hosts/nix-ws.nix;
in (baseConfig args).config.system.build.vmTest.override {
  # Disable network dependencies
  networking.useDHCP = false;
  services.tailscale.enable = false;
  
  # Enable fast build optimizations
  nix-fast-build.enable = true;
  
  # Minimal test configuration
  testEnv = {
    includeDesktop = false;
    runDuration = "short";
  };
}