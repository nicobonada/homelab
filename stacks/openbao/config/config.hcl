# Single-node OpenBao (file storage). Bind-mounted read-only into the container.
# Data dir is a separate host path (see compose.yaml).
ui = true

# OpenBao 2.x dropped mlock; do not set disable_mlock (see install hardening docs).

storage "file" {
  path = "/openbao/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  # Lab-only: no TLS at the process. Reach over Tailscale or localhost; add a
  # reverse-proxy cert later if needed. Do not expose 8200 to the public net.
  tls_disable = 1
}

# Advertise loopback inside the container; clients set BAO_ADDR to the host.
api_addr = "http://127.0.0.1:8200"
