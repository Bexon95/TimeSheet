@echo off
setlocal EnableExtensions
if not defined ProgramFiles^(x86^) set "ProgramFiles(x86)=C:\Program Files (x86)"

set "SCRIPT_DIR=%~dp0"
set "ROOT=%SCRIPT_DIR%.."
set "FLUTTER=%ROOT%\..\Cashy\.tools\flutter\bin\flutter.bat"

if exist "%ROOT%\.tools\flutter\bin\flutter.bat" (
  set "FLUTTER=%ROOT%\.tools\flutter\bin\flutter.bat"
)

if not exist "%FLUTTER%" (
  echo ERROR: Flutter SDK not found at %FLUTTER% >&2
  exit /b 1
)

for %%D in ("%ROOT%\..\Cashy\.tools\jdk-21") do (
  if exist "%%~fD\bin\java.exe" set "JAVA_HOME=%%~fD"
)
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"

call "%FLUTTER%" %*
