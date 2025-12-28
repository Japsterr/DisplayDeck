# DisplayDeck Mobile (FMX)

Cross-platform FMX app (Android-first) to manage DisplayDeck: login/register, list and claim displays, view campaigns.

## Prereqs
- RAD Studio with FMX (Community/Professional or higher) and Android SDK configured
- Set API base URL in `MobileApp/Config/uAppConfig.pas`:
  - Local Emulator: `http://10.0.2.2:2001`
  - Production: `http://api.displaydeck.co.za`

## Project
- `MobileApp/DisplayDeckMobile.dpr`
- Forms: `Forms/fLogin.*`, `Forms/fMain.*`
- Services: `uApiClient`, `uAuthService`, `uDisplayService`, `uCampaignService`
- Models: `uModels`

## Features
- Login / Register against `/auth/login` and `/auth/register`
- Persist JWT in memory (can be extended to TPreferences / Secure Storage)
- Displays tab: list `/organizations/{OrganizationId}/displays` and claim via `/organizations/{OrgId}/displays/claim`
- Campaigns tab: list `/organizations/{OrganizationId}/campaigns`

## Run (Android)
1. Open `MobileApp/DisplayDeckMobile.dpr` in RAD Studio
2. Select Android target
3. Ensure the API is reachable from device/emulator (update BaseUrl if needed)
4. Run on emulator or device

### Command-line build (optional)
If RAD Studio is installed locally, you can build the APK via PowerShell:

1) Build APK

```powershell
cd c:\DisplayDeck\MobileApp
./build-android.ps1 -Configuration Debug -Platform Android64
```

2) Install on emulator/device with adb

```powershell
adb install -r "<full path to APK printed by the script>"
```

Notes:
- The included `AndroidManifest.template.xml` enables cleartext HTTP for development so the app can call `http://10.0.2.2:2001`. Use HTTPS in production.

## Next steps
- Persist token securely (Android KeyStore / iOS Keychain)
- Add media upload flow (presigned URLs)
- Assign campaigns to displays and schedule windows
- QR code scanner to fetch ProvisioningToken automatically
- App theming and responsive layout
