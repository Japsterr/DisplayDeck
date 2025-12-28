@echo off
setlocal
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"

rem Ensure the Win32 Debug output EXE is not locked (common when app is still running)
taskkill /F /IM DisplayDeckManager.exe >nul 2>nul

msbuild DisplayDeckManager\DisplayDeckManager.dproj /t:Clean /p:Config=Debug;Platform=Win32
if errorlevel 1 goto :fail
msbuild DisplayDeckManager\DisplayDeckManager.dproj /t:Build /p:Config=Debug;Platform=Win32
if errorlevel 1 goto :fail
echo Build SUCCEEDED
exit /b 0
:fail
echo Build FAILED
exit /b 1
endlocal
