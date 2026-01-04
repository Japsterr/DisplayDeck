@echo off
rem Build script for DisplayDeck Delphi server
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
msbuild Server\Linux\DisplayDeck.WebBroker.dproj /t:Build /p:Config=Release;Platform=Linux64
if errorlevel 1 (
  echo Build FAILED
  exit /b 1
) else (
  echo Build SUCCEEDED
)
