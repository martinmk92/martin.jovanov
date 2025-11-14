[CmdletBinding()]
param(
    [string]$LogDirectory = "$env:ProgramData\\IntuneMonthlyUpdates",
    [switch]$Silent,
    [int]$MaxRuntimeMinutes = 90
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('s')
    $entry = "[$timestamp][$Level] $Message"

    if (-not $Silent.IsPresent) {
        Write-Host $entry
    }

    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $entry
    }
}

function Ensure-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw 'Dieses Skript muss mit administrativen Rechten ausgeführt werden.'
    }
}

function Initialize-Logging {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $script:LogFile = Join-Path -Path $LogDirectory -ChildPath "Install-MonthlyUpdates-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    New-Item -ItemType File -Path $script:LogFile -Force | Out-Null
    Write-Log -Message "Logging initialisiert: $script:LogFile"
}

function Save-State {
    param(
        [bool]$RebootRequired,
        [string]$Status
    )

    $state = [ordered]@{
        LastRunUtc     = (Get-Date).ToUniversalTime().ToString('o')
        RebootRequired = $RebootRequired
        Status         = $Status
    }

    $statePath = Join-Path -Path $LogDirectory -ChildPath 'state.json'
    $state | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
}

try {
    Ensure-Administrator
    Initialize-Logging

    Write-Log -Message 'Starte Suche nach verfügbaren Qualitätsupdates.'

    $startTime = Get-Date
    $deadline = $startTime.AddMinutes($MaxRuntimeMinutes)

    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()

    $criteria = "IsInstalled=0 and Type='Software' and IsHidden=0"
    $searchResult = $searcher.Search($criteria)

    if ($searchResult.Updates.Count -eq 0) {
        Write-Log -Message 'Keine neuen Updates gefunden.'
        Save-State -RebootRequired:$false -Status 'NothingToInstall'
        exit 0
    }

    Write-Log -Message ("{0} Updates gefunden. Filtere nach Updates ohne Benutzereingriff." -f $searchResult.Updates.Count)

    $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($update in $searchResult.Updates) {
        if ($update.InstallationBehavior.CanRequestUserInput) {
            Write-Log -Message "Überspringe '$($update.Title)' (erfordert Benutzereingriff)." -Level 'WARN'
            continue
        }
        if ($update.EulaAccepted -eq $false) {
            Write-Log -Message "Akzeptiere EULA für '$($update.Title)'."
            $update.AcceptEula()
        }
        [void]$updatesToInstall.Add($update)
        Write-Log -Message "Füge '$($update.Title)' zur Installation hinzu."
    }

    if ($updatesToInstall.Count -eq 0) {
        Write-Log -Message 'Keine automatisch installierbaren Updates verfügbar.' -Level 'WARN'
        Save-State -RebootRequired:$false -Status 'FilteredOut'
        exit 0
    }

    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $updatesToInstall

    Write-Log -Message ("Beginne Installation von {0} Updates." -f $updatesToInstall.Count)
    $result = $installer.Install()

    for ($i = 0; $i -lt $updatesToInstall.Count; $i++) {
        $update = $updatesToInstall.Item($i)
        $resultCode = $result.GetUpdateResult($i).ResultCode
        Write-Log -Message ("Installationsergebnis für '$($update.Title)': $resultCode")
    }

    $overallResult = $result.ResultCode
    $rebootRequired = $result.RebootRequired

    Write-Log -Message "Gesamtergebnis: $overallResult. Neustart erforderlich: $rebootRequired"

    $status = if ($overallResult -eq 2) { 'Success' } elseif ($overallResult -eq 3) { 'SuccessWithErrors' } else { $overallResult }
    Save-State -RebootRequired:$rebootRequired -Status $status

    if ($rebootRequired) {
        Write-Log -Message 'Ein Neustart ist erforderlich.' -Level 'WARN'
        exit 3010
    }

    if ($overallResult -eq 2 -or $overallResult -eq 3) {
        exit 0
    } else {
        Write-Log -Message "Installation wurde mit ResultCode $overallResult beendet." -Level 'ERROR'
        exit 1
    }
}
catch {
    Write-Log -Message $_.Exception.Message -Level 'ERROR'
    Save-State -RebootRequired:$false -Status 'Failed'
    exit 1
}
finally {
    if ($script:LogFile -and (Test-Path $script:LogFile)) {
        Write-Log -Message 'Skriptlauf abgeschlossen.'
    }
}
