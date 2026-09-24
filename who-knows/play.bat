@echo off
rem Launches the game (the project's main scene). Double-click to play.
rem Set GODOT_BIN to override the Godot executable path.
setlocal
if not defined GODOT_BIN set "GODOT_BIN=D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe"
if not exist "%GODOT_BIN%" (
    echo Godot not found at %GODOT_BIN%. Set GODOT_BIN.
    pause
    exit /b 1
)
start "" "%GODOT_BIN%" --path "%~dp0." %*
