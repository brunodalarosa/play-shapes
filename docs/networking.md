# Networking

How the host and phones reach each other on the LAN, what to check when a phone cannot
connect, and how the host's network settings are overridden locally. Setting up HTTPS for
test phones is in [local-https.md](local-https.md). The messages themselves are in
[protocol.md](protocol.md).

## How it works

- `SessionHost` starts its own TCP HTTP and WebSocket services, on all interfaces by default,
  on separate ports 8080 and 8081.
- The lobby discovers IPv4 addresses and sends `SessionHost.join_url` directly to its QR and
  address display.
- Phones fetch the session metadata, then connect or resume over WebSocket protocol 1.
- There is no Node server, no mDNS or Bonjour discovery, no environment framework and no
  Internet dependency.
- TLS listeners use Godot's `StreamPeerTLS`, shared by HTTP and WebSocket through
  `ControllerStream`. No extra server or runtime dependency is needed.
- Hard-coded HTTP or WS URLs outside this path are test fixtures, preview fixtures or
  documentation. Fixtures explicitly opt out of workstation overrides.

## Safety

- Listeners bind the configured LAN interfaces.
- The HTTP and WS defaults are supported, and so are explicitly provisioned HTTPS and WSS.
- Registry reconnect tokens authenticate player input.
- There is no public hosting and no CORS API.
- Never forward ports 8080 or 8081 to the Internet.
- Keep local networking and certificate configuration outside tracked Resources and
  standalone packages.

## When a phone cannot connect

Check, in this order:

1. The address selected in the lobby belongs to the adapter the phone can reach.
2. Both TCP ports are reachable.
3. The phone is on the same Wi-Fi.
4. The network is not a guest network and has no client isolation.
5. A VPN is not restricting LAN access.
6. Windows Firewall allows the host.

The user handles private-network permission prompts. The tooling does not change firewall or
VPN settings.

If a service port is busy, boot shows Retry. If the WebSocket cannot bind, the host rolls
HTTP back rather than staying half started.

## Local network configuration

The host reads an optional JSON file that overrides its network settings:

- In the editor and in development: ignored `local/network.json` beside the project.
- In a standalone build: `local/network.json` beside the executable.
- Anywhere: the path in the `PLAY_SHAPES_NETWORK_CONFIG` environment variable.
- The value `off` for that variable ignores local overrides. Tests use it.
- Relative PEM paths resolve beside the JSON file.

```json
{
  "tls_enabled": true,
  "bind_address": "*",
  "advertised_host": "",
  "http_port": 8080,
  "websocket_port": 8081,
  "certificate_path": "certificate.pem",
  "private_key_path": "key.pem"
}
```

Restart the host after changing it.

## HTTPS and WSS

With `tls_enabled` true:

- The lobby QR and address use HTTPS, and session discovery selects WSS.
- An empty advertised hostname keeps the explicit LAN-IP selection.
- The certificate must cover that IP, or the advertised hostname, and be trusted on the phone.
- There is no mDNS advertisement. The certificate has to name the address phones use.

Before either listener binds, `ControllerTLS` checks that the PEM material is readable, that
the leaf certificate is valid against the host clock, and that the private and public keys
match.

- Both listeners start, or neither does.
- Slow TLS, HTTP and WebSocket handshakes are bounded by the request timeout.
- There is no insecure fallback and no way to bypass browser verification.

To return to HTTP, set `tls_enabled` to false or remove the local override, then restart.

Certificates are provisioned with `node tools/local_https.mjs setup --ip LAN_IP`. Setup never
changes system trust. The commands, the per-phone steps and how to undo them are in
[local-https.md](local-https.md).
