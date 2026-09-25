@echo off
setlocal EnableExtensions
cd /d "%~dp0.."
git config core.hooksPath .githooks
echo Git hooks installed (core.hooksPath=.githooks)
