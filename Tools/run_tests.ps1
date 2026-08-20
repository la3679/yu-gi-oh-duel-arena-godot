# Headless test runner (Windows / PowerShell).
#
# Two things this works around, both learned the hard way:
#
#  1. Godot writes a lot to stderr (every push_error prints a full GDScript backtrace).
#     Piping stdout+stderr through PowerShell can block on a full pipe, so the run uses
#     Start-Process with explicit file redirection and prints the files afterwards.
#  2. A test suite that fails to COMPILE makes RunTests._initialize() throw before it can
#     call quit(), which leaves the headless SceneTree running forever. A parse check runs
#     first so a compile error is an immediate, readable failure instead of a hang.
#
# The Godot Windows binary does not report a usable process exit code here, so success is
# decided by the "RESULT:" line the suite prints. This script's OWN exit code is
# authoritative: 0 on pass, 1 on failure — CI depends on that.
#
#   powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1                # full suite
#   powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 SmokeCheck     # a different entry script
#   powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 -Import        # refresh the class cache, run nothing
#
# Godot is located in this order:
#   1. -GodotPath argument
#   2. $env:GODOT_BIN, then $env:GODOT
#   3. godot / godot4 on PATH
#   4. a Godot_v4.*-stable_win64.exe under the WinGet package directory
#   5. the default Steam install location

param(
    [string]$Script = "RunTests",
    [int]$TimeoutSeconds = 600,
    [string]$GodotPath = "",
    [switch]$Import
)

$ErrorActionPreference = "Stop"

# The project root is the parent of the directory holding this script. Never hard-code it:
# this file is public and must not embed anyone's home directory.
$project = Split-Path -Parent $PSScriptRoot

function Resolve-Godot([string]$Explicit) {
    if ($Explicit -and (Test-Path $Explicit)) { return (Resolve-Path $Explicit).Path }
    foreach ($v in @($env:GODOT_BIN, $env:GODOT)) {
        if ($v -and (Test-Path $v)) { return (Resolve-Path $v).Path }
    }
    foreach ($n in @("godot", "godot4", "Godot_v4.7.1-stable_win64.exe")) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c) { return $c.Source }
    }
    $winget = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path $winget) {
        $hit = Get-ChildItem -Path $winget -Recurse -Filter "Godot_v4.*-stable_win64.exe" `
            -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    $steam = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
    if (Test-Path $steam) { return $steam }
    return $null
}

$godot = Resolve-Godot $GodotPath
if (-not $godot) {
    Write-Output "----- GODOT NOT FOUND -----"
    Write-Output "Install Godot 4.7.x, then either put it on PATH, set GODOT_BIN, or pass -GodotPath."
    exit 1
}

$outDir = Join-Path $env:TEMP "duelarena-tests"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

function Invoke-Godot([string[]]$ExtraArgs, [string]$Tag, [int]$Timeout) {
    $o = Join-Path $outDir "$Script.$Tag.out.txt"
    $e = Join-Path $outDir "$Script.$Tag.err.txt"
    $godotArgs = @("--headless", "--path", "`"$project`"") + $ExtraArgs
    $p = Start-Process -FilePath $godot -ArgumentList $godotArgs -NoNewWindow -PassThru `
        -RedirectStandardOutput $o -RedirectStandardError $e
    $finished = $p.WaitForExit($Timeout * 1000)
    if (-not $finished) { $p.Kill(); Write-Output "TIMEOUT after $Timeout seconds" }
    $text = ""
    if (Test-Path $o) { $text += (Get-Content $o -Raw) }
    if (Test-Path $e) { $text += (Get-Content $e -Raw) }
    return @{ text = $text; stdout = $o; stderr = $e; finished = $finished }
}

Write-Output "Godot:   $godot"
Write-Output "Project: $project"

# --- 0. optional import pass -----------------------------------------------
# Godot only registers a new `class_name` after an import pass, and the parse check below
# reads the class cache. Run this as its OWN invocation after adding a new class: chaining
# it into the test run is not enough, the parse check still sees the stale cache.
if ($Import) {
    Invoke-Godot @("--import") "import" 300 | Out-Null
    Write-Output "IMPORT: done"
    exit 0
}

# --- 1. parse check --------------------------------------------------------
$check = Invoke-Godot @("--check-only", "--script", "res://Scripts/tests/$Script.gd") "check" 180
$parseErrors = $check.text -split "`n" | Where-Object { $_ -match "Parse Error|Compile Error|Failed to (load|compile)" }
if ($parseErrors) {
    Write-Output "----- PARSE CHECK FAILED -----"
    $parseErrors | ForEach-Object { Write-Output $_.TrimEnd() }
    exit 1
}

# --- 2. the run ------------------------------------------------------------
$run = Invoke-Godot @("--script", "res://Scripts/tests/$Script.gd") "run" $TimeoutSeconds

Write-Output "----- stdout -----"
if (Test-Path $run.stdout) { Get-Content $run.stdout }
$errLines = @()
if (Test-Path $run.stderr) { $errLines = Get-Content $run.stderr }
if ($errLines.Count -gt 0) {
    Write-Output "----- stderr ($($errLines.Count) lines, first 40) -----"
    $errLines | Select-Object -First 40
}

# RunTests prints "RESULT: PASS"; SmokeCheck prints "SMOKE CHECK: PASS".
# A timeout is a failure even if a PASS line was printed before the hang.
if (-not $run.finished) {
    Write-Output "RUNNER: FAIL (timeout)"
    exit 1
}
if ($run.text -match "RESULT:\s*PASS" -or $run.text -match "SMOKE CHECK:\s*PASS") {
    Write-Output "RUNNER: PASS"
    exit 0
} else {
    Write-Output "RUNNER: FAIL"
    exit 1
}
