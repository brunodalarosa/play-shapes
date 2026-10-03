# 0010. Phones find the host by IP address, not by name

Recorded on 2026-10-03 from the project's documents, where it was already in force. The reasons are as those documents gave them; whoever made the decision should correct them if they differ.

## Situation

A phone needs the host's address, and HTTPS needs a certificate that names that address. Name discovery with mDNS or Bonjour would give a friendly name, but needs its own advertisement, handling of duplicate names, packaging on each platform, and checking on every phone.

## Decision

There is no mDNS or Bonjour. The lobby shows a QR code and an address for an IP the user picks, and the certificate names that IP.

## What follows

- The certificate can also carry a hostname, but the host does not advertise it. A hostname is used only where resolution was set up and checked separately.
- TLS does not depend on discovery, so a checked hostname can be advertised later.
