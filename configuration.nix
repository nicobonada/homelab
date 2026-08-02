{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking = {
    hostName = "homelab";
    networkmanager.enable = true;
  };

  time.timeZone = "America/Toronto";

  users.users.nico = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
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

  services.openssh.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  services.resolved.enable = true;

  services.technitium-dns-server = {
    enable = true;
    openFirewall = true;
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "nixos-smb";
        "security" = "user";
        "map to guest" = "Bad User";
      };
      music = {
        path = "/mnt/backup-drive/music";
        browseable = "yes";
        writable = "no";
        "guest ok" = "no";
      };
    };
  };
  services.samba-wsdd.enable = true;

  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    defaultEditor = true;
  };

  programs.nh.enable = true;

  security.sudo.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
