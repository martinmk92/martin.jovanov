[CmdletBinding()]
param(
    [string]$LogDirectory = "$env:ProgramData\\IntuneMonthlyUpdates",
    [int]$MaxAgeDays = 35
)

$ErrorActionPreference = 'Stop'

$statePath = Join-Path -Path $LogDirectory -ChildPath 'state.json'
if (-not (Test-Path -Path $statePath)) {
    Write-Output 'Statusdatei wurde nicht gefunden.'
    exit 1
}

try {
    $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
}
catch {
    Write-Output 'Statusdatei konnte nicht gelesen werden.'
    exit 1
}

if (-not $state.LastRunUtc) {
    Write-Output 'Statusdatei enthält kein LastRunUtc-Feld.'
    exit 1
}

$lastRun = Get-Date $state.LastRunUtc
$age = (Get-Date).ToUniversalTime() - $lastRun.ToUniversalTime()

if ($age.TotalDays -gt $MaxAgeDays) {
    Write-Output "Letzter Installationslauf liegt länger als $MaxAgeDays Tage zurück."
    exit 1
}

if ($state.RebootRequired -eq $true) {
    Write-Output 'Es ist noch ein Neustart ausstehend.'
    exit 1
}

if ($state.Status -ne 'Success' -and $state.Status -ne 'SuccessWithErrors' -and $state.Status -ne 'NothingToInstall') {
    Write-Output "Letzter Status: $($state.Status)."
    exit 1
}

Write-Output 'Monatliche Updates wurden innerhalb des definierten Zeitraums installiert.'
exit 0
