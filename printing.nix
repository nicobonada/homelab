{
  pkgs,
  ...
}:
{
  # HL-1210W is host-based. Its IPP service advertises an empty pdl
  # and rejects jobs, so phones cannot print to the printer directly.
  # brlaser renders the page; the queue sends it to raw port 9100.
  # CUPS on this host advertises AirPrint / IPP Everywhere.
  # mDNS name, not a DHCP address. This repo is public.
  services.printing = {
    enable = true;
    drivers = [ pkgs.brlaser ];
    # Stay up at boot. Socket activation would not advertise until
    # some local client connects.
    startWhenNeeded = false;
    # Phones need IPP. The admin web UI stays off.
    webInterface = false;
    defaultShared = true;
    browsing = true;
    listenAddresses = [ "*:631" ];
    # Connected networks only. Does not name a subnet in git.
    allowFrom = [ "@LOCAL" ];
    openFirewall = true;
    # Avahi would otherwise start cups-browsed, which would ingest
    # the printer's broken IPP advertisement.
    browsed.enable = false;
    # Phones treat a self-signed IPPS listener as unavailable.
    extraConf = ''
      DefaultEncryption Never
    '';
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  hardware.printers = {
    ensureDefaultPrinter = "HL-1210W";
    ensurePrinters = [
      {
        name = "HL-1210W";
        description = "Brother HL-1210W via homelab";
        deviceUri = "socket://BRN0468749CBD60.local:9100";
        model = "drv:///brlaser.drv/br1210.ppd";
        ppdOptions.PageSize = "A4";
      }
    ];
  };
}
