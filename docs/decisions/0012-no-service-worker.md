# 0012. No service worker and no cache on the phone

Recorded on 2026-10-03 from the project's documents, where it was already in force. The reasons are as those documents gave them; whoever made the decision should correct them if they differ.

## Situation

The phone page can be installed as an app. Installed web apps often use a service worker to cache files, which adds versioning and invalidation, and can serve stale session data.

## Decision

There is no service worker and no cache. Every route is served with `no-store`, and the LAN host serves every file each time.

## What follows

- Chrome's install prompt does not require a service worker, so installation still works.
- Updating phones is: rebuild the bundle, restart the host, reload the page.
- The app cannot run without the host, and installing it does not establish certificate trust.
