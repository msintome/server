@echo off
REM ============================================================
REM   AmalieXI - LandSandBoat startup script
REM ============================================================

set SERVER_PATH=C:\ffxi\server

echo Starting LSB servers...
echo.

REM Start xi_connect (login server) - first
start "xi_connect (login)" /D "%SERVER_PATH%" cmd /k xi_connect.exe
timeout /t 2 /nobreak >nul

REM Start xi_world (world manager) - second
start "xi_world" /D "%SERVER_PATH%" cmd /k xi_world.exe
timeout /t 2 /nobreak >nul

REM Start xi_search (auction house / search) - third
start "xi_search" /D "%SERVER_PATH%" cmd /k xi_search.exe
timeout /t 2 /nobreak >nul

REM Start xi_map (zones / scripts) - last, takes longest to load
start "xi_map" /D "%SERVER_PATH%" cmd /k xi_map.exe

echo.
echo All four servers launched in separate windows.
echo xi_map takes 10-30 seconds to fully load all zones.
echo.
echo Close each window manually to shut down a server cleanly.
echo Or run stop-server.bat to kill them all.
echo.

REM Start AH broker bot
start "ahbot (broker)" /D "C:\ffxi\ffxiahbot\bin" cmd /k uv run ffxiahbot broker --inp-csv items.csv --buy-items --sell-items

pause