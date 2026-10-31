{ ... }:
{
  # Caddy compose publishes 80/443 on 0.0.0.0 so Docker does not bind a
  # specific Tailscale address. That HostIp bind fails on dockerd restart
  # (moby#51758 / #53928) and leaves the container Up with empty Networks.
  #
  # DOCKER-USER is Docker's hook in FORWARD (published ports DNAT off INPUT).
  # Allow tailscale0 and compose bridges (Gatus hairpin to
  # dashboard.lab.bonada.ca); drop 80/443 from the LAN NIC. Other published
  # app ports stay as they are.
  networking.firewall.extraCommands = ''
    caddy_docker_filter() {
      local ipt=$1
      $ipt -N DOCKER-USER 2>/dev/null || true
      $ipt -N nixos-caddy-filter 2>/dev/null || true
      $ipt -F nixos-caddy-filter
      $ipt -A nixos-caddy-filter -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
      $ipt -A nixos-caddy-filter -i tailscale0 -j RETURN
      $ipt -A nixos-caddy-filter -i docker0 -j RETURN
      $ipt -A nixos-caddy-filter -i br+ -j RETURN
      $ipt -A nixos-caddy-filter -p tcp -m multiport --dports 80,443 -j DROP
      $ipt -A nixos-caddy-filter -p udp --dport 443 -j DROP
      $ipt -C DOCKER-USER -j nixos-caddy-filter 2>/dev/null \
        || $ipt -I DOCKER-USER -j nixos-caddy-filter
    }
    caddy_docker_filter "iptables -w"
    caddy_docker_filter "ip6tables -w"
  '';
}
