@echo off
setlocal EnableExtensions
cd /d "%~dp0.."

if "%~1"=="--check" (
  bash scripts/check.sh
  if errorlevel 1 exit /b 1
  shift
)

call scripts\flutter.bat build apk --release --split-per-abi --target-platform android-arm64 -Pforce-version-code-ignoring-abi=true %*
if errorlevel 1 exit /b 1

for /f "usebackq tokens=2 delims=: " %%v in (`findstr /b "version:" pubspec.yaml`) do set "VERSION_LINE=%%v"
for /f "tokens=1 delims=+" %%a in ("%VERSION_LINE%") do set "VERSION_NAME=%%a"

set "SRC=build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
set "DEST=build\app\outputs\flutter-apk\timesheet-%VERSION_NAME%.apk"
copy /y "%SRC%" "%DEST%" >nul

echo Built %DEST%
endlocal
exit /b 0
