# Requires RAD Studio/Delphi installed locally. Adjust paths if needed.
param(
  [string]$Configuration = "Debug",
  [string]$Platform = "Android64",
  [string]$Target = "Build",
  [switch]$Package, # Build the .deployproj to produce an APK
  [switch]$Install,
  [string]$AdbPath = "C:\Users\Public\Documents\Embarcadero\Studio\23.0\CatalogRepository\AndroidSDK-2525-23.0.55362.2017\platform-tools\adb.exe",
  [string]$AvdManager = "C:\Users\Public\Documents\Embarcadero\Studio\23.0\CatalogRepository\AndroidSDK-2525-23.0.55362.2017\cmdline-tools\16.0\bin\avdmanager.bat",
  [string]$AvdName = ""
)

$ErrorActionPreference = 'Stop'

function Find-RsVars {
  $candidates = @(
    'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat',
    'C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat',
    'C:\Program Files (x86)\Embarcadero\Studio\21.0\bin\rsvars.bat'
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  $found = Get-ChildItem 'C:\Program Files (x86)\Embarcadero' -Recurse -Filter rsvars.bat -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  if ($found) { return $found }
  throw 'rsvars.bat not found. Please install RAD Studio/Delphi and Android SDK.'
}

$projectName = 'DisplayDeckMobile'
# Always drive msbuild via the .dproj; use Deploy target when -Package is set
if ($Package) {
  $proj = Join-Path $PSScriptRoot ("$projectName.dproj")
  # Build then Deploy to produce APK
  $msbuildTarget = 'Build;Deploy'
} else {
  $proj = Join-Path $PSScriptRoot ("$projectName.dproj")
  $msbuildTarget = $Target
}
if (!(Test-Path $proj)) { throw "Project not found: $proj" }

$rs = Find-RsVars
Write-Host "Using rsvars: $rs"

# Call rsvars.bat then msbuild in same process
$cmd = "`"$rs`" && msbuild `"$proj`" /t:$msbuildTarget /p:Config=$Configuration /p:Platform=$Platform"
cmd.exe /c $cmd
if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }

# Try to locate APK output
$binDir = Join-Path $PSScriptRoot ("$Platform\$Configuration")
$apk = Get-ChildItem $binDir -Recurse -Include *.apk -ErrorAction SilentlyContinue | Select-Object -First 1
if ($apk) {
  Write-Host "APK: $($apk.FullName)"
  if ($Install) {
    if (!(Test-Path $AdbPath)) { throw "adb not found at $AdbPath" }
    & $AdbPath devices | Out-Host
    & $AdbPath install -r $apk.FullName | Out-Host
  }
} else {
  if ($Package) {
    Write-Warning "APK not found in $binDir after packaging. Check deploy configuration and output paths in the IDE."
  } else {
    Write-Warning "APK not found in $binDir. Use -Package to build the .deployproj for APK packaging."
  }
}
