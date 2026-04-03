# Colleague Clock

A native macOS menu bar app that shows teammates, their assigned time zones, and the current local time for each person.

## What It Does

- Lives in the macOS menu bar with a compact AppKit popover and companion full app window
- Lets you add a person and assign a time zone
- Stores entries locally as JSON in `~/Library/Application Support/ColleagueClock/clock-entries.json`
- Updates displayed times automatically
- Supports searching by city, country, or time zone identifier
- Uses bundled IANA TZDB data, so customer machines do not need a current macOS time zone database for correct clock rules

## Requirements

- macOS 13 or later
- Swift 6 toolchain
- Full Xcode is recommended if you want to run and debug it as a regular macOS app

## Run

From Terminal:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run
```

If you prefer Xcode, open `Package.swift` in Xcode and run the `TimeZoneMenuBar` executable target.

If your machine is still pointed at Command Line Tools instead of full Xcode, regular `swift build` or `swift run` may fail with an SDK/toolchain mismatch. In that case, either keep using the `DEVELOPER_DIR=...` prefix above or switch the active developer directory to Xcode.

## Package For Sharing

To assemble a double-clickable macOS app bundle plus a ZIP and DMG:

```bash
./Tools/package-release.sh
```

Artifacts are written under `dist/<version>/`.

Default metadata used by the packaging script:

- App name: `Colleague Clock`
- Bundle identifier: `com.mukhtharcm.colleagueclock`
- Version: `0.1.0`
- Build number: `1`

You can override them when packaging:

```bash
APP_NAME="Colleague Clock" \
BUNDLE_IDENTIFIER="com.mukhtharcm.colleagueclock" \
VERSION="0.1.0" \
BUILD_NUMBER="1" \
./Tools/package-release.sh
```

If you want to sign locally, pass your Developer ID identity explicitly:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./Tools/package-release.sh
```

If you leave `SIGNING_IDENTITY` unset, the packager will try to auto-detect a single installed `Developer ID Application` identity on your local Mac. The repo does not hardcode any personal signing identity or team identifier.

## App Icon

The packaged app bundle includes `Packaging/AppIcon.icns`.

To regenerate it from the checked-in drawing script:

```bash
./Tools/generate-app-icon.sh
```

## Notarize For Distribution

Apple’s current notarization workflow uses `xcrun notarytool`, and Apple recommends storing credentials in the keychain rather than embedding passwords directly in scripts.

Set up a keychain profile once:

```bash
xcrun notarytool store-credentials "colleague-clock-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID1234" \
  --password "app-specific-password"
```

Then notarize the packaged DMG and staple both the app and the DMG:

```bash
NOTARYTOOL_PROFILE="colleague-clock-notary" \
./Tools/notarize-release.sh
```

If you prefer not to use a keychain profile, the script also accepts direct credentials:

```bash
APPLE_ID="you@example.com" \
TEAM_ID="TEAMID1234" \
APP_SPECIFIC_PASSWORD="app-specific-password" \
./Tools/notarize-release.sh
```

The notarization script expects a signed app bundle and DMG from `./Tools/package-release.sh`. It writes the Apple notary response log to `dist/<version>/notary-log.json`.

## GitHub Actions

The repo ships with two workflows under `.github/workflows`:

- `ci.yml` builds, tests, packages an unsigned app, and uploads the ZIP and DMG as workflow artifacts
- `release.yml` can sign, notarize, and publish release assets when the required secrets are configured

Repository variables:

- `BUNDLE_IDENTIFIER` (recommended; keeps the signed app on a stable identifier instead of relying on the fallback)
- `APP_NAME` (optional; defaults to `Colleague Clock`)

Repository secrets for signed releases:

- `BUILD_CERTIFICATE_BASE64`: base64-encoded Developer ID `.p12`
- `P12_PASSWORD`: password for the exported `.p12`
- `KEYCHAIN_PASSWORD`: temporary keychain password used on the runner
- `SIGNING_IDENTITY`: full certificate common name, for example `Developer ID Application: Your Name (TEAMID)`
- `APPLE_ID`
- `APP_SPECIFIC_PASSWORD`
- `TEAM_ID`

Example for generating the certificate secret payload on macOS:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

On GitHub-hosted macOS runners, the release workflow imports the certificate into a temporary keychain, runs `./Tools/package-release.sh`, then runs `./Tools/notarize-release.sh` when the Apple notarization secrets are present.

Forked pull requests still work for normal CI, but GitHub does not expose repository secrets to workflows triggered from forks, so only the main repository can produce signed and notarized builds from Actions.

## Bundled TZDB

The app ships with bundled IANA tz data resources under `Sources/TimeZoneMenuBar/Resources/TZDB`.

The current bundled version is:

```text
2026a
```

To refresh the bundled tz database later:

```bash
./Tools/update-tzdb.sh 2026a
```
