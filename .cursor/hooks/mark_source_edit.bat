@echo off
setlocal EnableExtensions
cd /d "%~dp0..\.."
call scripts\flutter.bat pub run scripts/hooks/mark_source_edit.dart
