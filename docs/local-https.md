# Local HTTPS for test phones

How to give the host a certificate that controlled test phones trust, so phone sensors work
over the LAN. It is for the owners' and developers' own phones; it is not a way to bring
guests in without certificates. How the host uses the certificate is in
[networking.md](networking.md#https-and-wss).

Everything needed for play is served on the LAN. Internet is needed only once, to download
the certificate tool. Testing uses **Chrome on iPhone and Android**.

## Enable HTTPS

Run from the repository root. Node 22 or newer is used for tooling only.

```powershell
node tools/local_https.mjs download
node tools/local_https.mjs ips
node tools/local_https.mjs setup --ip 192.168.1.20
godot --path .
```

Replace `192.168.1.20` with the host's reachable Wi-Fi or Ethernet IPv4 address, from the
lobby or from `ips`. The script requires this choice; it does not guess between adapters.

What each step does:

- `download` saves the official pinned mkcert v1.4.4 binary inside ignored `local/tools`. You
  may instead install mkcert yourself, or pass `--mkcert FULL_PATH`.
- `setup` creates an isolated certificate authority in `local/ca`, the leaf PEM files, and
  `local/network.json`. It does not change system trust.
- `setup` reuses valid matching material.
- `regenerate --ip NEW_IP` renews the leaf after an address change and keeps the root.
- The configured IP is the advertised join address, so the QR code and the certificate stay
  aligned even when other adapters are present.

## Trust the root on the host

Checking the page in Chrome on the host itself needs the root to be trusted there:

```powershell
node tools/local_https.mjs trust
```

- The command announces the trust-store change and may ask for elevation.
- It is never part of automatic setup.

## What to copy to a phone

- Compare the root SHA-256 printed by `setup` with the certificate you install.
- Transfer **only** `local/Play-Shapes-Dev-CA.cer` to phones, using a trusted local file
  transfer.
- Never transfer `local/ca/rootCA-key.pem` or `local/key.pem`.
- Windows file permissions are inherited from your private user checkout. Keep that checkout
  and the `ca` folder private.
- No local credentials are tracked or packaged.

## Chrome on iPhone

1. Open the public `.cer` file on the iPhone; iOS offers a profile download. Install it in
   Settings > Profile Downloaded (or General > VPN & Device Management), checking the
   certificate identity. Menu details vary with iOS; follow the current
   [Apple profile guidance](https://support.apple.com/en-us/102400).
2. Enable the root in Settings > General > About > Certificate Trust Settings > Enable full
   trust for root certificates. Installing the profile alone is not enough. See
   [Apple's trust instructions](https://support.apple.com/en-us/102390).
3. Open **Chrome**, scan the host's HTTPS QR code or type its exact HTTPS address, and finish
   the normal color and name joining. No TLS warning is acceptable. Check that the host IP
   matches the certificate before going on.
4. Record the iPhone model, the iOS version and the Chrome version.

A result from desktop or Android Chrome says nothing about iPhone behavior. Feature-detect the
APIs iPhone Chrome exposes. Sensor permission must follow the phone's button gesture.

## Chrome on Android

1. Install the public `.cer` through the device's security settings as a **CA certificate**.
   The path is commonly Settings > Security & privacy > More security settings > Encryption &
   credentials > Install a certificate > CA certificate. It varies by manufacturer and
   version; record the actual steps.
2. Open Chrome and check that the HTTPS QR code loads without a warning.
3. Record the Android version, the Chrome version and the device model.

Do not assume native apps trust user-installed roots because browser testing works.

## Safari

Safari is not set up. To investigate it:

- Opening `/session.json` directly separates HTTPS and session discovery from a WebSocket
  failure.
- The public root profile must be installed **and** explicitly enabled for SSL/TLS under
  iPhone Certificate Trust Settings. Accepting a page warning does not establish full root
  trust. See [Apple's full-trust instructions](https://support.apple.com/en-ie/102390).

## Disable, regenerate or remove trust

```powershell
node tools/local_https.mjs regenerate --ip 192.168.1.20
node tools/local_https.mjs disable
node tools/local_https.mjs untrust
```

- Restart Godot after `setup`, `regenerate` or `disable`.
- `disable` turns TLS off. It keeps the files and the existing trust.
- `untrust` removes only this isolated development root from the host's stores.
- On iPhone, remove the specific profile in General > VPN & Device Management. On Android,
  remove this root from user credentials. Do not clear unrelated certificates.
- Keep the certificate authority until every device has removed its trust, if you intend to
  delete its local files.

## Standalone builds

- Put `local/network.json` and the leaf material it references beside the exported
  executable.
- The certificate authority's private keys stay on the workstation that created them.
- The default Resources remain portable and contain no secrets.

## Hostnames

Phones find the host by IP address. There is no mDNS or Bonjour advertisement.

- `setup --ip LAN_IP --hostname playshapes.local` adds the name to the certificate. It
  **does not advertise it**.
- Add `--advertise-hostname` only if name resolution is configured separately and checked on
  every test phone.
- If the name fails, run `setup` or `regenerate` with just the current IP and restart. Do not
  keep an HTTPS hostname whose certificate does not cover the fallback address.
