# Networking

## Networking, export, and operational warnings

- Listeners bind the configured LAN interfaces. HTTP/WS defaults and explicitly provisioned HTTPS/WSS are supported; registry reconnect tokens authenticate player input. There is no public hosting or CORS API. Never forward ports 8080/8081 to the Internet.
- If a phone cannot connect, check the selected adapter, both TCP ports, same Wi-Fi, guest/client isolation, VPN LAN restrictions, and Windows Firewall. The user handles private-network permission prompts; tooling does not change firewall or VPN settings.
- A busy service port shows Retry in boot. WebSocket bind failure rolls HTTP back rather than leaving a partial host.
- Editor/runtime checks do not prove a package. Smoke the exported executable without Godot or Node, including lobby, HTTP routes, WebSocket, and a browser connection.
- Preserve `web/public/`, the Kenyoni QR addon, external-PCK output, and the curated runtime/source-archive boundary in export changes.
- A phone reload creates a new transport connection but may resume the same player during grace. Duplicate active-token resume gives the newest tab ownership and closes the old connection.

## Network audit

Godot SessionHost starts custom TCP HTTP and WebSocket services on all interfaces by default, with separate 8080/8081 ports. The lobby discovers IPv4 addresses and sends SessionHost.join_url directly to its QR/address display. Phones obtain session metadata then connect/resume over WebSocket protocol 1. There is no Node server, mDNS/Bonjour discovery, environment framework, or Internet dependency. Hard-coded HTTP/WS URLs outside the canonical path are test/preview fixtures or documentation; fixtures explicitly opt out of workstation overrides. Keep local networking/certificate configuration outside tracked Resources and standalone packages. TLS listeners use Godot StreamPeerTLS, shared by HTTP and WebSocket via ControllerStream; no extra server/runtime dependency is required.

## Secure LAN transport

In editor/development, create ignored `local/network.json` (or select a JSON file with `PLAY_SHAPES_NETWORK_CONFIG`). In a standalone build, use `local/network.json` beside the executable. Relative PEM paths resolve beside the JSON file. Example:

```json
{"tls_enabled":true,"bind_address":"*","advertised_host":"","http_port":8080,"websocket_port":8081,"certificate_path":"certificate.pem","private_key_path":"key.pem"}
```

Restart the host. The lobby QR/address uses HTTPS and session discovery selects WSS; an empty advertised hostname keeps explicit LAN-IP selection. Certificates must cover that IP or the advertised hostname and be trusted on the phone. ControllerTLS checks readable PEM material, leaf validity against the host clock, and matching private/public keys before either listener binds. Both listeners start or neither does. Slow TLS/HTTP/WebSocket handshakes remain bounded by the existing request timeout. There is no insecure fallback or browser verification bypass. To return to HTTP, set `tls_enabled` false (or remove this local override), then restart. Do not install or modify trust implicitly. Use `node tools/local_https.mjs setup --ip LAN_IP` for certificate provisioning; see [controlled-device HTTPS and motion testing](local-https-and-motion-testing.md) for exact enable/regenerate/disable commands, optional explicit host trust, Chrome iPhone/Android root installation, and the physical-device checklist. No system trust changes occur during setup. mDNS advertisement is intentionally deferred; explicit IP/SAN alignment is the initial controlled-test discovery strategy.

Verification: `godot --headless --path . --script tests/controller_tls_test.gd` generates disposable ignored fixture material; `node --test tests/tls.test.mjs` in web verifies HTTPS asset loading, WSS join/resume, rejection of untrusted and wrong-host certificates, and service availability alongside stalled handshakes. Test clients explicitly trust only their fixture certificate; they never disable verification. Secret file patterns and local configuration are ignored and excluded from both export presets.
