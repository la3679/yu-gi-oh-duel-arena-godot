# Headless test runner.
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
# decided by the "RESULT:" line the suite prints.
#
#   powershell -File Tools\run_tests.ps1               # full suite
#   powershell -File Tools\run_tests.ps1 SmokeCheck    # a different entry script

param(
    [string]$Script = "RunTests",
    [int]$TimeoutSeconds = 300
)

$godot = "C:\Users\lovea\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe"
$project = "C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame"
$outDir = Join-Path $env:TEMP "duelarena-tests"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

function Invoke-Godot([string[]]$ExtraArgs, [string]$Tag, [int]$Timeout) {
    $o = Join-Path $outDir "$Script.$Tag.out.txt"
    $e = Join-Path $outDir "$Script.$Tag.err.txt"
    $args = @("--headless", "--path", "`"$project`"") + $ExtraArgs
    $p = Start-Process -FilePath $godot -ArgumentList $args -NoNewWindow -PassThru `
        -RedirectStandardOutput $o -RedirectStandardError $e
    $finished = $p.WaitForExit($Timeout * 1000)
    if (-not $finished) { $p.Kill(); Write-Output "TIMEOUT after $Timeout seconds" }
    $text = ""
    if (Test-Path $o) { $text += (Get-Content $o -Raw) }
    if (Test-Path $e) { $text += (Get-Content $e -Raw) }
    return @{ text = $text; stdout = $o; stderr = $e; finished = $finished }
}

# --- 1. parse check ---
$check = Invoke-Godot @("--check-only", "--script", "res://Scripts/tests/$Script.gd") "check" 120
$parseErrors = $check.text -split "`n" | Where-Object { $_ -match "Parse Error|Compile Error|Failed to (load|compile)" }
if ($parseErrors) {
    Write-Output "----- PARSE CHECK FAILED -----"
    $parseErrors | ForEach-Object { Write-Output $_.TrimEnd() }
    exit 1
}

# --- 2. the run ---
$run = Invoke-Godot @("--script", "res://Scripts/tests/$Script.gd") "run" $TimeoutSeconds

Write-Output "----- stdout -----"
if (Test-Path $run.stdout) { Get-Content $run.stdout }
$errLines = @()
if (Test-Path $run.stderr) { $errLines = Get-Content $run.stderr }
if ($errLines.Count -gt 0) {
    Write-Output "----- stderr ($($errLines.Count) lines, first 40) -----"
    $errLines | Select-Object -First 40
}
if ($run.text -match "RESULT:\s*PASS") { Write-Output "RUNNER: PASS" } else { Write-Output "RUNNER: FAIL" }
