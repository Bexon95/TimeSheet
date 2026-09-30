# TimeSheet

Local Android time-tracking app for multiple workplaces/projects, with dashboard, calendar, timer, statistics, and Honorarnote-style PDF invoices.

## Flutter SDK

Uses the same Flutter SDK as the Cashy app (`../Cashy/.tools/flutter`). The build scripts resolve it automatically.

## Setup

```bash
cd TimeSheet
bash scripts/check.sh   # optional: analyze + tests
```

`android/local.properties` points to the Cashy Flutter SDK and your Android SDK.

## Run on device/emulator

```bash
bash scripts/resolve_flutter.sh
# then from Git Bash, with Flutter on PATH from that script:
../Cashy/.tools/flutter/bin/flutter.bat run
```

Or open the project in Android Studio and run from there.

## Build release APK (sideload)

Same as Cashy:

```bash
bash scripts/build_apk.sh
```

With tests first:

```bash
bash scripts/build_apk.sh --check
```

Output: `build/app/outputs/flutter-apk/timesheet-<version>.apk` (arm64)

Build (if needed) and install — usual entry point. Rebuilds when the versioned APK is missing or older than `pubspec.yaml` / `lib/**/*.dart`; skips the build when it is already up to date. Installs via adb when a device is connected; otherwise prints a warning after building.

```bash
bash scripts/install_apk.sh
```

```powershell
.\scripts\install_apk.bat
```

Build only (no adb):

```powershell
.\scripts\build_apk.bat
```

## Features

- Reorderable workplace drawer with hourly rates
- Dashboard with grand total + per-workplace breakdown
- Calendar (month/week/day), manual entries, edit/delete
- Start/stop timer with persistence
- Statistics with money/hours bar chart
- Honorarnote PDF invoices with history and re-share

## First launch

1. Open the left drawer and add a workplace.
2. Select the workplace in the app bar.
3. Use **+** to add entries or start a timer.
4. Configure invoice sender details under **Rechnung → settings**.

## Locale

German (`de_DE`) formatting and EUR currency.
