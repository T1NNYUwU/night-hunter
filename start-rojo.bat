@echo off
title Rojo Server - Night Hunter (port 34872)
cd /d "%~dp0"
echo Serving night-hunter on port 34872. Keep this window open, then press Connect in Studio.
where rojo >nul 2>nul
if %errorlevel%==0 (
    rojo serve default.project.json
) else if exist "%LOCALAPPDATA%\Rojo\rojo.exe" (
    "%LOCALAPPDATA%\Rojo\rojo.exe" serve default.project.json
) else (
    echo Rojo CLI not found. Install it from https://github.com/rojo-rbx/rojo/releases
)
pause
