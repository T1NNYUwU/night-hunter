@echo off
title Rojo Server (with map) - Night Hunter (port 34872)
cd /d "%~dp0"
if not exist "map\Furniture.rbxmx" (
    echo map\Furniture.rbxmx not found. Run git pull, or ask the map owner to export the map. See docs\map-workflow.md
    pause
    exit /b 1
)
if not exist "map\AssetLibrary.rbxmx" (
    echo map\AssetLibrary.rbxmx not found. Run git pull, or ask the map owner to export the map. See docs\map-workflow.md
    pause
    exit /b 1
)
echo Serving code + map on port 34872. Use this on YOUR OWN COPY of the place, not the shared Team Create place.
echo Keep this window open, then press Connect in Studio.
where rojo >nul 2>nul
if %errorlevel%==0 (
    rojo serve with-map.project.json
) else if exist "%LOCALAPPDATA%\Rojo\rojo.exe" (
    "%LOCALAPPDATA%\Rojo\rojo.exe" serve with-map.project.json
) else (
    echo Rojo CLI not found. Install it from https://github.com/rojo-rbx/rojo/releases
)
pause
