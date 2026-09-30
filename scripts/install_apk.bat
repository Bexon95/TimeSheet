@echo off
setlocal EnableExtensions
cd /d "%~dp0.."

for /f "usebackq tokens=2 delims=: " %%v in (`findstr /b "version:" pubspec.yaml`) do set "VERSION_LINE=%%v"
for /f "tokens=1 delims=+" %%a in ("%VERSION_LINE%") do set "VERSION_NAME=%%a"

set "APK=build\app\outputs\flutter-apk\timesheet-%VERSION_NAME%.apk"
set "NEED_BUILD=0"

if not exist "%APK%" set "NEED_BUILD=1"

if "%NEED_BUILD%"=="0" (
  powershell -NoProfile -Command "$apk=Get-Item '%APK%'; if ((Get-Item 'pubspec.yaml').LastWriteTime -gt $apk.LastWriteTime) { exit 2 }; if (Get-ChildItem -Path 'lib' -Recurse -Filter '*.dart' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $apk.LastWriteTime } | Select-Object -First 1) { exit 2 }"
  if errorlevel 2 set "NEED_BUILD=1"
)

if "%NEED_BUILD%"=="1" (
  call scripts\build_apk.bat %*
  if errorlevel 1 exit /b 1
)

set "FOUND="
for /f "skip=1 tokens=1,2" %%a in ('adb devices 2^>nul') do (
  if "%%b"=="device" set "FOUND=1"
)

if defined FOUND (
  adb install -r "%APK%"
  if errorlevel 1 exit /b 1
  echo Installed on device: %APK%
) else (
  echo WARNING: No Android device connected ^(adb^). Built: %APK%
)

endlocal
exit /b 0
