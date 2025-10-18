@echo off
setlocal
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
msbuild "Server\Linux\DisplayDeck.WebBroker.dproj" /t:Build /p:Config=Release /p:Platform=Linux64
if errorlevel 1 (
  echo Linux build FAILED
  exit /b 1
) else (
  echo Linux build SUCCEEDED
)
endlocal
