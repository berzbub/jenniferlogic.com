# Golden Harbour Hospital Management System (GHMS)

SwiftUI/SwiftData iOS app (iOS 17+) plus data spec (`DATA_DRAFT.txt`). Apache 2.0 — see `NOTICE`
(add the full Apache-2.0 text as `LICENSE`).

## Build (on a Mac)
1. `brew install xcodegen && cd golden-harbour-ghms && xcodegen generate`
2. Open `GoldenHarbour.xcodeproj`, set your Team and bundle ID under Signing & Capabilities.
3. Add a 1024x1024 PNG to `GHMS/Assets.xcassets/AppIcon.appiconset` (and its filename in Contents.json).
4. Run on a real iPhone (speech and notifications need a device).

## Publish
1. Join the Apple Developer Program.
2. Product > Archive > Distribute App > App Store Connect.
3. In App Store Connect: set the privacy policy URL to https://jenniferlogic.com/golden-harbour-privacy.html, complete App Privacy answers, then use TestFlight and submit for review.
4. Link your site to the App Store page once approved (iOS apps can't be installed by direct download).

## Before real hospital use
Encrypted storage, staff login, a secure backend, HIPAA/GDPR review, and a backend service for real SMS.
