# Intune Paket: Monatliche Windows Updates

Dieses Paket stellt zwei PowerShell-Skripte bereit, die als Win32-App über Microsoft Intune verteilt werden können, um monatlich Qualitätsupdates zu installieren.

## Dateien

| Datei | Beschreibung |
| --- | --- |
| `Install-MonthlyUpdates.ps1` | Sucht nach verfügbaren Windows-Qualitätsupdates, installiert diese automatisch und schreibt den Status in eine Log- sowie Statusdatei. Gibt den Exit-Code `3010` zurück, wenn ein Neustart erforderlich ist. |
| `Detect-MonthlyUpdates.ps1` | Dient als Erkennungsskript für Intune. Prüft, ob das Installationsskript innerhalb eines definierten Zeitraums erfolgreich ausgeführt wurde und kein Neustart aussteht. |

## Vorbereitung

1. Kopieren Sie beide Skripte in einen Arbeitsordner, z. B. `C:\Intune\MonthlyUpdates`.
2. (Optional) Passen Sie Standardparameter wie das Log-Verzeichnis oder die maximale Ausführungsdauer an.

## Verpackung als Win32-App

1. Öffnen Sie eine administrative PowerShell-Sitzung.
2. Erstellen Sie eine IntuneWin-Datei:
   ```powershell
   # Pfade anpassen
   $sourceFolder = 'C:\Intune\MonthlyUpdates'
   $setupFile = 'Install-MonthlyUpdates.ps1'
   $outputFolder = 'C:\Intune\Output'

   .\IntuneWinAppUtil.exe -c $sourceFolder -s $setupFile -o $outputFolder
   ```
3. Laden Sie die erzeugte `.intunewin`-Datei im Intune Admin Center als neue Win32-App hoch.
4. Wählen Sie als Installationsbefehl z. B.:
   ```
   powershell.exe -ExecutionPolicy Bypass -File .\Install-MonthlyUpdates.ps1 -Silent
   ```
5. Hinterlegen Sie als Erkennungsskript die Datei `Detect-MonthlyUpdates.ps1` und setzen Sie bei Bedarf den Parameter `-MaxAgeDays`.
6. Konfigurieren Sie Zuweisungen und Zeitpläne entsprechend Ihrer Update-Strategie (z. B. monatlich vor dem Patchday).

## Logging und Status

- Standardmäßig werden Log- und Statusdateien unter `%ProgramData%\IntuneMonthlyUpdates` gespeichert.
- Die Statusdatei `state.json` enthält das Datum der letzten erfolgreichen Ausführung sowie, ob ein Neustart erforderlich ist.
- Für Fehleranalysen stehen detaillierte Logdateien zur Verfügung, die nach Zeitstempeln benannt sind.

## Exit-Codes

- `0` – Installation erfolgreich oder keine Updates gefunden.
- `3010` – Installation erfolgreich, Neustart erforderlich.
- `1` – Fehler bei der Installation oder Vorbereitung.

## Hinweise

- Das Installationsskript filtert Updates, die Benutzereingaben erfordern, automatisch aus.
- Stellen Sie sicher, dass Geräte Zugriff auf Windows Update oder den internen WSUS/SUP haben.
- Planen Sie einen automatischen Neustart über Intune oder andere Mechanismen, wenn ein Neustart erforderlich ist.
