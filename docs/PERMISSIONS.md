# Sensitive Permissions Documentation

This document lists every sensitive permission the Tourist Safety app requests, why it's needed, and where in the UI the user is informed. This information is required for Google Play Console's "Data Safety" section.

---

## Permissions Summary

| Permission | Android Manifest | When Requested | Module | User-Facing Rationale |
|------------|-----------------|----------------|--------|----------------------|
| Fine Location | `ACCESS_FINE_LOCATION` | First SOS tap or first map open | `sos_core`, `live_tracking` | "To send your exact location to emergency contacts and authorities during a crisis" |
| Coarse Location | `ACCESS_COARSE_LOCATION` | With fine location | `sos_core`, `live_tracking` | (Requested as part of fine location) |
| Background Location | `ACCESS_BACKGROUND_LOCATION` | After fine location granted, when user enables background tracking | `live_tracking` | "To keep tracking your location when the app is in the background, so help can find you even if you can't open the app" |
| Microphone | `RECORD_AUDIO` | When user enables passive detection (Phase 2) | `passive_detection` | "To detect distress sounds like screams automatically — audio is analyzed on your device only and never sent to any server" |
| Activity Recognition | `ACTIVITY_RECOGNITION` | When user enables passive detection (Phase 2) | `passive_detection` | "To detect falls or struggles using your phone's motion sensors" |
| Bluetooth | `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` | When user enables offline BLE mesh (Phase 2) | `ble_mesh` | "To relay emergency signals to nearby Tourist Safety users when there's no internet — your phone becomes a lifeline for others" |
| Foreground Service | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | Automatically when background tracking starts | `live_tracking`, `passive_detection` | Shown via persistent notification: "Tourist Safety is monitoring for your safety" |
| Internet | `INTERNET` | Always (no runtime prompt) | All | Standard network access |
| Wake Lock | `WAKE_LOCK` | Always (no runtime prompt) | Background services | Keeps sensors active during monitoring |
| Vibrate | `VIBRATE` | Always (no runtime prompt) | Alerts | Haptic feedback for alerts |
| Push Notifications | `POST_NOTIFICATIONS` (Android 13+) | First buddy group join or first alert received | `buddy_geofence` | "To alert you when a group member moves too far away" |

---

## Data Collection & Usage

| Data Type | Collected | Stored On Device | Sent to Server | Retention | Purpose |
|-----------|-----------|------------------|----------------|-----------|---------|
| GPS Location | Yes | Cached locally | During SOS + tracking | 30 days on server | Emergency response, live tracking |
| Audio | Analyzed on-device | Never stored raw | Never | N/A | On-device scream detection only |
| Motion/Accelerometer | Analyzed on-device | Never stored raw | Never | N/A | On-device fall/struggle detection |
| Bluetooth proximity | Yes | Temporarily | Relay metadata only | Until delivered | Offline emergency relay |
| User profile | Yes | Locally | On registration | Account lifetime | Authentication |
| Emergency contacts | Yes | Locally + server | On setup | Account lifetime | Emergency notification |

---

## Permission Denial Handling

The app must **never crash** if a permission is denied. Behavior for each denial:

| Permission Denied | App Behavior |
|-------------------|-------------|
| Fine Location | SOS still fires but without GPS coordinates; user is warned "Location unavailable — emergency sent without position" |
| Background Location | Tracking stops when app is backgrounded; user is informed with a banner |
| Microphone | Passive audio detection disabled; other detection (kinetic) still works if permitted |
| Activity Recognition | Passive kinetic detection disabled; audio detection still works if permitted |
| Bluetooth | BLE mesh relay disabled; online path still works; offline payloads queued locally |
| Notifications | Buddy alerts won't show as push; visible only when app is open |

---

## Play Console Data Safety Answers

| Question | Answer |
|----------|--------|
| Does your app collect or share any of the required user data types? | Yes |
| Is all of the data collected by your app encrypted in transit? | Yes (HTTPS + AES-256-GCM) |
| Do you provide a way for users to request that their data is deleted? | Yes (account deletion endpoint) |
| Location: Approximate location | Collected, not shared with third parties |
| Location: Precise location | Collected, not shared with third parties |
| Audio: Voice or sound recordings | NOT collected — analyzed on-device only, never stored or sent |
| App activity | Not collected |
| Device or other IDs | Device UUID collected for BLE mesh deduplication only |

---

## iOS App Privacy (Nutrition Label) — For Future Use

| Data Type | Linked to Identity | Used for Tracking | Purpose |
|-----------|-------------------|-------------------|---------|
| Precise Location | Yes | No | App Functionality |
| Coarse Location | Yes | No | App Functionality |
| Audio Data | No | No | App Functionality (on-device only) |
| Device ID | No | No | App Functionality (BLE relay) |
