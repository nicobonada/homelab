{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./vzdump-b2.nix
    ./syncthing.nix
    ./music-backup.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  swapDevices = [
    {
      device = "/swapfile";
      size = 2048; # MB
    }
  ];

  # flakes + nix-command come from the Determinate Nix module; keep trusted rebuilders.
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  networking = {
    hostName = "homelab";
    networkmanager.enable = true;
  };

  time.timeZone = "America/Toronto";

  users.users.nico = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
    ];
    # Workstation keys (seyruun + oakhill) for classic SSH when Tailscale is off.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDfCbF/qHMrvFvPF3pwN78vu/HV9zLATmy1m0H+9wUl3 nico@seyruun"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiS0WGMF1xtibs+k+4WjkpPCv0stUUGY7E75Nuh2Fib nico@oakhill"
    ];
    packages = with pkgs; [
      tree
      duf
      bat
      btop
      htop
    ];
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    wget
    git
  ];

  services.qemuGuest.enable = true;

  virtualisation.docker = {
    enable = true;
    daemon.settings.dns = [
      "100.100.100.100" # Tailscale MagicDNS
      "1.1.1.1"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      # Keys + Tailscale SSH only (workstation keys declared above).
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    # Tailscale SSH (identity) as primary remote path; see ACLs in tailscale-policy.
    extraSetFlags = [ "--ssh" ];
  };
  services.resolved.enable = true;

  services.technitium-dns-server = {
    enable = true;
    openFirewall = true;
  };
  # DoH forwarders need a default route. network.target is too early after a
  # cold start / power outage (cloudflare-dns.com:443 = network unreachable).
  systemd.services.technitium-dns-server = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  # Music library replication is Syncthing (syncthing.nix → /mnt/pve-backup/music),
  # not Samba. Keep samba off unless something else needs a share.
  services.samba = {
    enable = false;
  };
  services.samba-wsdd.enable = false;

  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    defaultEditor = true;
  };

  programs.nh.enable = true;

  security.sudo = {
    enable = true;
    # Single-admin VM: workstations deploy with
    #   nh os switch . -H homelab --target-host nico@homelab -e passwordless
    # (or nixos-rebuild --target-host … --elevate sudo). Remote activation runs
    # `sudo sh -c 'nix-env …'` / switch-to-configuration — path-exact NOPASSWD
    # rules cannot cover that. Root SSH stays off (PermitRootLogin = no).
    wheelNeedsPassword = false;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
