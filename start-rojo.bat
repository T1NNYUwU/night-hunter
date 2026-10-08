@echo off
title Rojo Server - Night Hunter (port 34872)
cd /d "%~dp0"
echo Serving night-hunter on port 34872. Keep this window open, then press Connect in Studio.
rojo serve default.project.json
pause
