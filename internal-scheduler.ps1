
$ErrorActionPreference = "Stop"
$group = $args[0]

if ($group -eq $null) {
    Write-Host ""
    Write-Host "usage: .\internal-scheduler.ps1 {0|1|2}"
    Write-Host ""
    Write-Error "Error: No update group specified."
}

Write-Host ""
Write-Host "Will schedule the following events for hosts in patch group '${group}':"
Write-Host ""

$now = Get-Date
$forceRebootTime = $now.Date.AddHours(22)
Write-Host "Forced reboot at:      $forceRebootTime"
$updateDefinitionsTime = $now.Date.AddHours(22).AddMinutes(50)
Write-Host "Definitions update at: $updateDefinitionsTime"
$avScanTime = $now.Date.AddDays(1).AddHours(3)
Write-Host "Antivirus scan at:     $avScanTime"

Write-Host ""

$scheduledTaskGpo = "Update scheduling - P$group"
Write-Host "Loading the GPO for scheduled tasks: $scheduledTaskGpo"
$backup = Backup-GPO -Name $scheduledTaskGpo -Path C:\TEMP

$xmlPath = "$($backup.BackupDirectory)\{$($backup.Id)}\DomainSysvol\GPO\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml"

$xml = New-Object -TypeName XML
$xml.Load($xmlPath)
foreach ($task in $xml.ScheduledTasks.TaskV2) {
    if ($task.name -eq 'Reboot') {
        $task.Properties.Task.Triggers.TimeTrigger.StartBoundary = $forceRebootTime.ToString("s")
        Write-Host "Successfully modified Reboot time."
    }
    if ($task.name -eq 'Update definitions') {
        $task.Properties.Task.Triggers.TimeTrigger.StartBoundary = $updateDefinitionsTime.ToString("s")
        Write-Host "Successfully modified Update definitions time."
    }
    if ($task.name -eq 'Run AV scan') {
        $task.Properties.Task.Triggers.TimeTrigger.StartBoundary = $avScanTime.ToString("s")
        Write-Host "Successfully modified Run AV scan time."
    }
}
$xml.Save($xmlPath)
Write-Host "Importing changes back into GPO: $scheduledTaskGpo"
Restore-GPO -BackupId $backup.Id -Path $($backup.BackupDirectory) | Out-Null

Remove-Item -Recurse -Force "$($backup.BackupDirectory)\{$($backup.Id)}"
