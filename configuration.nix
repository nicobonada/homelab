{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./vzdump-b2.nix
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

  security.sudo = {
    enable = true;
    # Same scoped rebuild rights as workstations (nh + nixos-rebuild only).
    extraRules = [
      {
        users = [ "nico" ];
        commands = map (command: {
          inherit command;
          options = [ "NOPASSWD" ];
        }) [
          "/run/current-system/sw/bin/nh"
          "/run/current-system/sw/bin/nixos-rebuild"
        ];
      }
    ];
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
