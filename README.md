# Colleague Clock

A native macOS menu bar app for tracking teammates across time zones.

- Add people with a name and time zone
- See their current local time from the menu bar or companion window
- Search by city, country, or time zone identifier
- Use bundled IANA TZDB data instead of relying on the host macOS time zone database

Entries are stored locally in `~/Library/Application Support/ColleagueClock/clock-entries.json`.

## Development

Requires macOS 13+ and full Xcode.

Run from Terminal:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run
```

Or open `Package.swift` in Xcode and run the `TimeZoneMenuBar` target.

## Packaging

Build a local app bundle, ZIP, and DMG:

```bash
./Tools/package-release.sh
```

Artifacts are written to `dist/<version>/`.
The DMG is generated with `dmgbuild`, so it includes an `Applications` shortcut and styled Finder layout without briefly opening a Finder window during packaging.

The first run may install `dmgbuild` into a project-local cache under `.build/`.

Useful overrides:

```bash
VERSION="0.1.0" \
BUILD_NUMBER="1" \
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./Tools/package-release.sh
```

If `SIGNING_IDENTITY` is omitted, the script tries to auto-detect a single installed `Developer ID Application` certificate.

## Releases

The repo has two GitHub Actions workflows:

- `ci.yml` builds, tests, and uploads unsigned artifacts
- `release.yml` signs, notarizes, and publishes a release when the required variables and secrets are configured

Repository variables:

- `BUNDLE_IDENTIFIER`
- `APP_NAME`

Repository secrets:

- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `KEYCHAIN_PASSWORD`
- `SIGNING_IDENTITY`
- `APPLE_ID`
- `APP_SPECIFIC_PASSWORD`
- `TEAM_ID`

Create a release with:

```bash
git tag v0.1.0
git push origin v0.1.0
```

You can also trigger `Release` manually from GitHub Actions.

For local notarization after packaging a signed build:

```bash
APPLE_ID="you@example.com" \
TEAM_ID="TEAMID1234" \
APP_SPECIFIC_PASSWORD="app-specific-password" \
./Tools/notarize-release.sh
```

## Project Notes

- App icon source: `./Tools/generate-app-icon.sh`
- Bundled tzdb version: `2026a`
- Refresh tzdb with: `./Tools/update-tzdb.sh 2026a`
