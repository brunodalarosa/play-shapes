# Controlled-device HTTPS and motion testing

This setup is for the owner/developers and controlled test phones. It does not solve certificate-free guest onboarding. Everything needed for play is served on the LAN; Internet is needed only to obtain development tools initially. Safari/PWA improvements and production architecture selection are deferred. The owner's first evaluation uses **Chrome on iPhone and Android**.

## Enable secure development

Run from the implementation repository (`play-shapes`). Node 22+ is tooling only.

```powershell
node tools/local_https.mjs download
node tools/local_https.mjs ips
node tools/local_https.mjs setup --ip 192.168.1.20
godot --path .
```

Replace `192.168.1.20` with the host's reachable Wi-Fi/Ethernet IPv4 address from the lobby or `ips`. The script deliberately requires this choice rather than guessing between adapters. The download command saves the official pinned mkcert v1.4.4 binary inside ignored `local/tools`; alternatively install mkcert yourself or use `--mkcert FULL_PATH`. Setup creates an isolated CA in `local/ca`, leaf PEM files and `local/network.json`, without changing system trust. It reuses valid matching material; `regenerate --ip NEW_IP` renews the leaf after an address change while retaining the root. The configured IP is the advertised join address, so QR and certificate SAN stay aligned even when other adapters are present.

Host Chrome verification additionally requires intentional local root trust:

```powershell
node tools/local_https.mjs trust
```

This command clearly announces the trust-store change and may require elevation. It is never part of automatic setup. Compare the root SHA-256 printed by setup with the certificate you install. Transfer **only** `local/Play-Shapes-Dev-CA.cer` to phones using a trusted local file transfer. Never transfer `local/ca/rootCA-key.pem` or `local/key.pem`. Windows file ACLs inherit from your private user checkout; keep that checkout/CA folder private. No local credentials are tracked or packaged.

## Chrome on iPhone

1. Open the public `.cer` file on the controlled iPhone; iOS offers a profile download. Install it via Settings > Profile Downloaded (or General > VPN & Device Management), verifying the certificate identity. Menu details vary with iOS; follow the current [Apple profile guidance](https://support.apple.com/en-us/102400).
2. Enable that root in Settings > General > About > Certificate Trust Settings > Enable full trust for root certificates. Installing the profile alone is insufficient. See [Apple's trust instructions](https://support.apple.com/en-us/102390).
3. Open **Chrome**, scan the host's HTTPS QR or type its exact HTTPS address, and finish normal color/name joining. No TLS warning is acceptable; verify the host IP matches the certificate SAN before proceeding.
4. Use the F12 lab checklist below. Record iPhone model, iOS version and Chrome version. Feature-detect the APIs exposed by iPhone Chrome; a desktop/Android Chrome result does not establish iPhone behavior. Sensor permission must follow the phone button gesture.

## Chrome on Android

Install the public `.cer` through the device's security settings for a **CA certificate** (commonly Settings > Security & privacy > More security settings > Encryption & credentials > Install a certificate > CA certificate). Manufacturer/version paths vary; record the actual steps. Open Chrome and verify the HTTPS QR loads without a warning before testing. Do not assume native apps trust user-installed roots merely because browser testing works. Verify Android version, Chrome version and device model.

## Disable, regenerate, or remove trust

```powershell
node tools/local_https.mjs regenerate --ip 192.168.1.20
node tools/local_https.mjs disable
node tools/local_https.mjs untrust
```

Restart Godot after setup/regeneration/disable. Disable sets TLS false; it preserves files and existing trust. Untrust explicitly removes only this isolated development root from host stores. On iPhone remove the specific profile in General > VPN & Device Management; on Android remove this root from user credentials. Do not clear unrelated certificates. Keep the CA until all devices have removed its trust if you intend to delete its local files.

Standalone: put `local/network.json` and its referenced leaf material beside the exported executable (CA private keys should stay on the provisioning workstation). The default Resources remain portable and secret-free. `PLAY_SHAPES_NETWORK_CONFIG` can select another JSON path. An empty environment value intentionally runs HTTP defaults for tests; clear that override for normal testing.

## Discovery decision for controlled testing

No mDNS/Bonjour stack existed in the audit. Adding a daemon/service or a second server solely for this lab is not justified yet: advertisement, duplicate-name conflict handling, Windows/Linux packaging and phone resolution would need their own verified lifecycle. The initial solution uses explicit IP with matching SAN. TLS configuration does not depend on discovery and can later advertise a verified hostname.

`setup --ip LAN_IP --hostname playshapes.local` can include the name as an additional SAN, but **does not advertise it**. Only add `--advertise-hostname` if name resolution is independently configured and verified on every test phone. If it fails, regenerate/setup with just the current IP and restart; do not keep an HTTPS hostname whose certificate does not cover the fallback address. `.local` reachability and trust remain physical-device verification items, not assumptions. Production investigation remains deferred.

## F12 lab checklist

The lab is added by PS-076; use its phone **Request Motion Permission** action after joining as Player 1 (registry seat 1).

- QR opens the exact controller; HTTPS is warning-free, session metadata selects WSS, and no mixed-content failure occurs.
- Grant motion/orientation permission from the button. Verify supported/denied/error/no-events states, both API permissions if exposed, and nullable readings. Ordinary non-motion controls must still work after denial.
- Check orientation alpha/beta/gamma (degrees), angular velocity (degrees/s), acceleration and acceleration including gravity (m/s²). Compare flat, upright, face-down, left/right tilt and yaw with the host slab; recenter and rotate portrait/landscape. Relative heading is not a compass guarantee; acceleration is not phone position.
- Confirm sample age, sensor event frequency and transmitted/received rate. Check subjective delay and noise before tuning smoothing.
- Connect a second phone: its movements cannot update Player 1's display. Disconnect/reload/reconnect Player 1: stale data is labeled, identity stays pinned, and fresh events recover.
- Lock/unlock, switch Chrome away/back, return from a background tab, restart the lab and return to lobby. No frozen-live values, stuck controls or lingering streams are acceptable.
- Turn off Internet access while retaining Wi-Fi/LAN. Joining, permission, motion and reconnect must still work on the controlled trusted devices.
- Test normal lobby/READY/CANCEL/Bubbles before and after the lab on both phones. Test desktop no-sensor fallback separately.

Record each result with browser/device versions. Automated host/browser tests and Godot desktop captures do not approve physical motion accuracy, touch latency, phone lifecycle, game feel, or visuals. Owner approval/publication remains pending.
