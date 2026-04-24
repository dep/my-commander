<!-- Project-specific override. This file was auto-generated from agent-rules originally, -->
<!-- but has been customized for my-commander's SPM + Sparkle setup. -->

# Export Signed App (MyCommander)

## Description

Build, sign, notarize, and release a new version of MyCommander with Sparkle auto-update support.

## Prerequisites

- Developer ID Application certificate in login keychain
- `notarytool` keychain profile (see Setup)
- Sparkle EdDSA private key in keychain (generated once via `generate_keys`)
- `create-dmg` installed: `brew install create-dmg`
- Sparkle tools in `/tmp/sparkle-bin/bin/` (or update paths below)

## Setup: Store Notarization Credentials

```bash
source .env && xcrun notarytool store-credentials "notarytool" \
  --apple-id "$APPLE_EMAIL" \
  --team-id "299R8V27FZ" \
  --password "$APPLE_APP_PASSWORD"
```

## Setup: Sparkle Tools (one-time)

```bash
mkdir -p /tmp/sparkle-bin && cd /tmp/sparkle-bin && \
curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz" -o sparkle.tar.xz && \
tar -xf sparkle.tar.xz
```

## Step-by-Step

### 0. Bump the version

Edit `MyCommander.app/Contents/Info.plist`:

```xml
<key>CFBundleShortVersionString</key>
<string>x.y.z</string>
<key>CFBundleVersion</key>
<string>N</string>   <!-- increment -->
```

### 1. Build the release binary

```bash
swift build -c release && \
cp -f .build/release/MyCommander MyCommander.app/Contents/MacOS/MyCommander
```

### 2. Embed Sparkle.framework

```bash
BUILD_DIR=".build/arm64-apple-macosx/release"
[ -d "$BUILD_DIR/Sparkle.framework" ] || BUILD_DIR=".build/release"
mkdir -p MyCommander.app/Contents/Frameworks
rm -rf MyCommander.app/Contents/Frameworks/Sparkle.framework
cp -R "$BUILD_DIR/Sparkle.framework" MyCommander.app/Contents/Frameworks/
install_name_tool -add_rpath "@executable_path/../Frameworks" MyCommander.app/Contents/MacOS/MyCommander 2>/dev/null || true
```

### 3. Sign (Sparkle framework first, then app)

```bash
IDENTITY="Developer ID Application: Danny Peck (299R8V27FZ)"

# Sign Sparkle's XPC helpers and framework first (inside-out signing required)
codesign --force --timestamp --options runtime --sign "$IDENTITY" \
  MyCommander.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc 2>/dev/null || true
codesign --force --timestamp --options runtime --sign "$IDENTITY" \
  MyCommander.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc 2>/dev/null || true
codesign --force --timestamp --options runtime --sign "$IDENTITY" \
  MyCommander.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate 2>/dev/null || true
codesign --force --timestamp --options runtime --sign "$IDENTITY" \
  MyCommander.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app 2>/dev/null || true
codesign --force --timestamp --options runtime --sign "$IDENTITY" \
  MyCommander.app/Contents/Frameworks/Sparkle.framework

# Now sign the app itself
codesign --force --deep --timestamp --options runtime \
  --entitlements MyCommander.entitlements \
  --sign "$IDENTITY" \
  MyCommander.app

codesign --verify --deep --strict --verbose=2 MyCommander.app
```

### 4. Notarize + staple

```bash
rm -f /tmp/MyCommander-notarize.zip && \
ditto -c -k --keepParent MyCommander.app /tmp/MyCommander-notarize.zip && \
xcrun notarytool submit /tmp/MyCommander-notarize.zip --keychain-profile "notarytool" --wait && \
xcrun stapler staple MyCommander.app && \
spctl --assess --type execute --verbose MyCommander.app
```

### 5. Package as DMG

Replace `<version>` with the new version (e.g. `0.1.3`):

```bash
rm -rf /tmp/MyCommander-dmg-src && mkdir -p /tmp/MyCommander-dmg-src && \
cp -R MyCommander.app /tmp/MyCommander-dmg-src/ && \
rm -f ~/Desktop/MyCommander-<version>.dmg && \
create-dmg \
  --volname "MyCommander" \
  --volicon "/tmp/MyCommander-dmg-src/MyCommander.app/Contents/Resources/MyCommander.icns" \
  --window-pos 200 120 --window-size 660 400 --icon-size 160 \
  --icon "MyCommander.app" 180 170 --hide-extension "MyCommander.app" \
  --app-drop-link 480 170 \
  ~/Desktop/MyCommander-<version>.dmg \
  /tmp/MyCommander-dmg-src/
```

### 6. Sign the DMG for Sparkle

```bash
SIG=$(/tmp/sparkle-bin/bin/sign_update ~/Desktop/MyCommander-<version>.dmg)
echo "$SIG"
# Captures: sparkle:edSignature="..." length="..."
```

### 7. Update appcast.xml

Prepend a new `<item>` to `appcast.xml` at the repo root. Use the signature from step 6:

```xml
<item>
  <title>Version <version></title>
  <pubDate>Mon, 24 Apr 2026 19:00:00 +0000</pubDate>
  <sparkle:version><build-number></sparkle:version>
  <sparkle:shortVersionString><version></sparkle:shortVersionString>
  <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
  <description><![CDATA[<release notes HTML>]]></description>
  <enclosure
    url="https://github.com/dep/my-commander/releases/download/<version>/MyCommander-<version>.dmg"
    sparkle:edSignature="<edSignature from sign_update>"
    length="<length from sign_update>"
    type="application/octet-stream" />
</item>
```

Use `date -u "+%a, %d %b %Y %H:%M:%S +0000"` for `pubDate`.

### 8. Commit, push, release

```bash
git add MyCommander.app/Contents/Info.plist \
        MyCommander.app/Contents/CodeResources \
        MyCommander.app/Contents/_CodeSignature/ \
        appcast.xml && \
git commit -m "bump version to <version>" && \
git push

gh release create <version> --title "<version>" --notes "<release notes>" && \
gh release upload <version> ~/Desktop/MyCommander-<version>.dmg
```

**CRITICAL:** `appcast.xml` must be pushed to `main` — Sparkle fetches it from the raw GitHub URL configured in Info.plist (`SUFeedURL`). The DMG URL in the appcast must match the GitHub release asset URL.

## Expected Output

- `notarytool`: `status: Accepted`
- `spctl`: `accepted / source=Notarized Developer ID`
- `codesign --verify --deep`: no output (silent success)

## Artifacts

- Notarized app: `MyCommander.app` (in-repo)
- DMG: `~/Desktop/MyCommander-<version>.dmg`
- Appcast: `appcast.xml` (committed to main)
- GitHub release with DMG attached
