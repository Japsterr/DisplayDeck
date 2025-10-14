@echo off
rem Build script for DisplayDeck Delphi server
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
msbuild Server\DisplayDeck.dproj /t:Build /p:Config=Debug;Platform=Win32
if errorlevel 1 (
  echo Build FAILED
  exit /b 1
) else (
  echo Build SUCCEEDED
)
