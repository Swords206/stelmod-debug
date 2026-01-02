@echo off
REM ============================================================================
REM stelmod-debug - Windows Launcher (Minimal Menu)
REM ============================================================================

cd /d "%~dp0"

REM If command provided, run it directly
if NOT "%1"=="" (
    powershell -ExecutionPolicy Bypass -File "%~dp0stelmod-debug.ps1" %*
    goto :eof
)

REM No command - show interactive menu
:menu
cls
echo.
echo ================================================================
echo   stelmod-debug - Stellaris Mod Log Analyzer
echo ================================================================
echo.
echo   [1] Setup     - Configure for your mod (FIRST TIME)
echo   [2] Monitor   - LIVE log watcher (2 windows)
echo   [3] Help      - Show all commands
echo   [0] Exit
echo.
echo ================================================================
echo.

set /p choice="Enter choice (0-3): "

if "%choice%"=="1" goto setup
if "%choice%"=="2" goto monitor
if "%choice%"=="3" goto help
if "%choice%"=="0" goto :eof

echo Invalid choice. Try again.
timeout /t 2 >nul
goto menu

:setup
powershell -ExecutionPolicy Bypass -File "%~dp0stelmod-debug.ps1" setup
pause
goto menu

:monitor
powershell -ExecutionPolicy Bypass -File "%~dp0stelmod-debug.ps1" monitor
pause
goto menu

:help
powershell -ExecutionPolicy Bypass -File "%~dp0stelmod-debug.ps1" help
pause
goto menu
