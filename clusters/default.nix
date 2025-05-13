{ hive, ... }:
hive.cluster {
  nodes = {
    workstation = { role = "workstation"; };
    server = { role = "server"; };
    edge = { role = "edge"; };
  };
  roles = {
    workstation = import ../roles/workstation.nix;
    server = import ../roles/server.nix;
    edge = import ../roles/edge.nix;
  };
} 