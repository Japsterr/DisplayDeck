# DisplayDeck Android Player (V1)

This is a minimal Android (Kotlin) player app.

Current behavior:
- On first launch it shows a 6-character pairing code (no user input).
- You enter that code on the website when adding a display.
- Once paired, the device switches to showing the display name.

Notes:
- API base is fixed to `https://api.displaydeck.co.za`.

Roadmap (next): after pairing, switch from "show name" -> "play assigned content" + offline manifest + cached media + proof-of-play telemetry.

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

## Build (Android Studio)

Open `android-player/` in Android Studio and run the `app` configuration.
