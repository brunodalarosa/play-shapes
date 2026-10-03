# 0011. Local HTTPS never changes trust by itself

Recorded on 2026-10-03 from the project's documents, where it was already in force. The reasons are as those documents gave them; whoever made the decision should correct them if they differ.

## Situation

Phone sensors need HTTPS, and a LAN address has no public certificate. A private certificate authority works only on devices that trust it, and adding trust to a machine is a security change.

## Decision

Setting up local HTTPS creates an isolated certificate authority and a certificate, and changes no trust store. Trusting the root on the host is a separate, explicit command. Phones are given only the public certificate.

The host has no insecure fallback and no way to bypass certificate checks. Tests trust only their own fixture certificate.

## What follows

- This serves the owners' and developers' test phones. It is not a way to bring guests in.
- Safari and the installed app are not set up; testing uses Chrome on iPhone and Android.
- Private keys stay on the machine that created them and are never tracked or packaged.
