$ErrorActionPreference = "Stop"
$godot = $env:GODOT_BIN
if (-not $godot) {
    $godot = "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe"
}
if (-not (Test-Path $godot)) { throw "Godot not found at $godot. Set GODOT_BIN." }

& $godot --headless --path $PSScriptRoot -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json @args
exit $LASTEXITCODE
