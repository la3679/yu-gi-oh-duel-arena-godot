# Cross-process determinism check (Windows / PowerShell). The bash twin is
# Tools/check_determinism.sh; keep the two in step.
#
# Part of the backend acceptance gate (PROJECT_STATE.md §8, unit 3): runs
# Scripts/tests/DumpDuels.gd in two SEPARATE Godot processes and requires the per-duel digests
# to be identical. Same-process determinism is asserted inside ScriptedDuelTests; this proves a
# duel depends on nothing that differs between processes.
#
#   powershell -ExecutionPolicy Bypass -File Tools\check_determinism.ps1
#
# This script's exit code is authoritative: 0 = identical, 1 = anything else.

param([string]$GodotPath = "")

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot "run_tests.ps1"

$runs = @()
foreach ($i in 1..2) {
    $runnerArgs = @("-ExecutionPolicy", "Bypass", "-File", $runner, "DumpDuels")
    if ($GodotPath) { $runnerArgs += @("-GodotPath", $GodotPath) }
    $out = & powershell @runnerArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Output "DETERMINISM: FAIL (process $i did not pass)"
        $out | Select-Object -Last 20
        exit 1
    }
    $lines = @($out | Where-Object { $_ -like "DUEL *" })
    Write-Output "process ${i}:"
    $lines | ForEach-Object { Write-Output "  $_" }
    $runs += , $lines
}

if ($runs[0].Count -eq 0) {
    Write-Output "DETERMINISM: FAIL (no duel lines were printed)"
    exit 1
}
if ($runs[0].Count -ne $runs[1].Count -or (Compare-Object $runs[0] $runs[1])) {
    Write-Output "DETERMINISM: FAIL (the two processes disagree)"
    exit 1
}
Write-Output "DETERMINISM: PASS ($($runs[0].Count) duels identical across two processes)"
exit 0
