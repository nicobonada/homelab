{ config, ... }:
{
  # Personal NAR cache for seats (luciole, crawl-tiles, other cache misses).
  # Substituter URL is https://cache.lab.bonada.ca/<cache>. Caddy is the
  # door; :8080 is only so the compose proxy can hairpin via
  # host.docker.internal (same pattern as Technitium :5380).
  services.atticd = {
    enable = true;
    environmentFile = config.sops.templates."atticd.env".path;
    settings = {
      listen = "0.0.0.0:8080";
      "allowed-hosts" = [ "cache.lab.bonada.ca" ];
      "api-endpoint" = "https://cache.lab.bonada.ca/";
      "garbage-collection" = {
        interval = "12 hours";
        # Bound guest-root growth. Per-cache override is `attic cache
        # configure lab --retention-period`.
        "default-retention-period" = "90 days";
      };
    };
  };

  # SQLite + local NARs under StateDirectory. Do not put this on the T7
  # music/backup share. Move to a dedicated virtio disk if the guest root
  # gets tight.
  networking.firewall.allowedTCPPorts = [ 8080 ];

  sops = {
    secrets."atticd/token_rs256_secret_base64" = {
      sopsFile = ./secrets/atticd.yaml;
    };
    templates."atticd.env" = {
      content = ''
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder."atticd/token_rs256_secret_base64"}
      '';
      restartUnits = [ "atticd.service" ];
    };
  };
}
