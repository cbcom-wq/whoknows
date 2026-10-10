@echo off
rem Launches the game (the project's main scene). Double-click to play.
rem Before it starts, two headless passes run:
rem   1. the editor pass rebuilds the global class cache (a stale cache is the
rem      usual cause of "Identifier ... not declared" errors on launch);
rem   2. tools/check_scripts.gd loads every game script and scene.
rem If the check fails, its errors are shown and the game does not start.
rem Set GODOT_BIN to override the Godot executable path.
rem Set SKIP_CHECK=1 to start without the check.
setlocal
if not defined GODOT_BIN set "GODOT_BIN=D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe"
if not exist "%GODOT_BIN%" (
    echo Godot not found at %GODOT_BIN%. Set GODOT_BIN.
    pause
    exit /b 1
)
if defined SKIP_CHECK goto launch

rem The console build sends the passes' output to the log file we search.
set "GODOT_CONSOLE=%GODOT_BIN:.exe=_console.exe%"
if not exist "%GODOT_CONSOLE%" set "GODOT_CONSOLE=%GODOT_BIN%"
set "CHECK_LOG=%TEMP%\whoknows_check.log"
echo Checking scripts and scenes...
"%GODOT_CONSOLE%" --headless --editor --path "%~dp0." --quit > "%CHECK_LOG%" 2>&1
"%GODOT_CONSOLE%" --headless --path "%~dp0." --script res://tools/check_scripts.gd >> "%CHECK_LOG%" 2>&1
if errorlevel 1 goto failed
goto launch

:failed
echo.
echo The check found errors. The game was not started:
echo.
findstr /c:"SCRIPT ERROR" /c:"CHECK FAILED" /c:"ERROR:" "%CHECK_LOG%"
echo.
echo Full log: %CHECK_LOG%
pause
exit /b 1

:launch
start "" "%GODOT_BIN%" --path "%~dp0." %*
