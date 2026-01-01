# DisplayDeck Android Player

Kotlin-based player app used to pair a display and render assigned content.

## Current behavior

- On first launch, shows a 6-character pairing code.
- After pairing, polls the backend for assignments.
- Can display:
  - **Menus** (loads the public menu page in WebView)
  - **Campaigns** (plays a manifest of items)

Campaign item support:

- **Menu items**: loads the website menu renderer (`/display/menu/{token}`) in WebView.
- **Image items**: rendered via a minimal HTML wrapper using CSS `object-fit: cover` to better fill the screen (especially portrait images).
- **Video items**: rendered via native Media3/ExoPlayer for better reliability on older devices/boxes.

## Android TV notes

- The app advertises `LEANBACK_LAUNCHER` so it can appear in Android TV launchers.
- A `BOOT_COMPLETED` receiver is registered to start the app when the device boots.

Important: many low-cost Android TV boxes have OEM “Auto start / Startup manager / Background restrictions” settings.
If the app does not start at boot:

- Launch the app once manually after installing.
- Enable auto-start for DisplayDeck in the box settings.
- Disable battery optimizations/restrictions for the app (if present).

## Build (Docker)

If you don't want to install Android Studio yet, you can build a debug APK using Docker.

From repo root:

```powershell
cd C:\DisplayDeck\android-player

# Docker-only build (installs Android SDK tools into ./ .android-sdk, then builds app-debug.apk)
docker run --rm -v ${PWD}:/workspace -w /workspace gradle:8.2-jdk17 bash -lc '
set -euxo pipefail

apt-get update
apt-get install -y --no-install-recommends wget unzip ca-certificates

SDK_DIR=/workspace/.android-sdk
mkdir -p "$SDK_DIR/cmdline-tools"

if [ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
  cd "$SDK_DIR"
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
  unzip -q cmdline-tools.zip -d cmdline-tools
  rm -f cmdline-tools.zip
  mv cmdline-tools/cmdline-tools cmdline-tools/latest
fi

export ANDROID_SDK_ROOT="$SDK_DIR"
export ANDROID_HOME="$SDK_DIR"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

set +o pipefail
yes | sdkmanager --licenses >/dev/null
set -o pipefail

SC=$(printf "%b" "\\x3b")
PKG_PLATFORM="platforms${SC}android-34"
PKG_BUILD_TOOLS="build-tools${SC}34.0.0"

sdkmanager --update
sdkmanager "platform-tools" "$PKG_PLATFORM" "$PKG_BUILD_TOOLS"

printf "sdk.dir=%s\n" "$ANDROID_SDK_ROOT" > /workspace/local.properties

if [ ! -f ./gradlew ]; then
  gradle wrapper --gradle-version 8.2
fi
chmod +x ./gradlew
./gradlew :app:assembleDebug
'

# APK output:
# android-player/app/build/outputs/apk/debug/app-debug.apk
```

Notes:
- `compileSdk` is 34 because modern AndroidX libraries require it; this does NOT mean the device must run Android 14.
- Device support is controlled by `minSdk` (currently 24 = Android 7.0).

## Quick install

APK output:

- android-player/app/build/outputs/apk/debug/app-debug.apk

Install via ADB:

```powershell
adb install -r "android-player\app\build\outputs\apk\debug\app-debug.apk"
```

## Build (Android Studio)

Open `android-player/` in Android Studio and run the `app` configuration.
