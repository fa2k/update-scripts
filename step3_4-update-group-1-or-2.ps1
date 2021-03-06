﻿
$ErrorActionPreference = "Stop"

Write-Host "Step 3/4 -- Updating patch group."
Write-Host "Note: First check the status of previous group (0 or 1) using check-status.ps1 and manual methods."
Write-Host ""
Write-Host ""

$groupNumber = Read-Host -Prompt "Enter the group number to update, 1 or 2: "

$sourceGpoName = "General software install - P0"
$gpoName = "General software install - P$groupNumber"

Write-Host "Backing up settings from '$sourceGpoName'..."
$backup = Backup-GPO -Name $sourceGpoName -Path C:\TEMP
Write-Host "Importing settings into '$gpoName'..."
$targetGpo = Get-GPO -Name $gpoName
$targetGpo.Import($backup) | Out-Null

Write-Host "Reading the list of updates from a file..."
$updates = Get-Content -Path D:\updatelist.txt | `
                Where-Object { $_ } | ` # Not empty string
                ForEach-Object { Get-WsusUpdate -UpdateId $_ }

Write-Host "Approving security updates for PatchGroup$groupNumber-SecOnly..."
$updates | Where-Object Classification -eq Security | `
        Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup$groupNumber-SecOnly
$updates | Where-Object Classification -eq Critical | `
        Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup$groupNumber-SecOnly
        
Write-Host "Approving all updates for PatchGroup$groupNumber-All..."
$updates | Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup$groupNumber-All

Write-Host "Run the Cleanup Tool"
Get-WsusServer | 
    Invoke-WsusserverCleanup -CleanupObsoleteUpdates `
             -CleanupUnneededContentFiles -CompressUpdates `
             -DeclineExpiredUpdates -DeclineSupersededUpdates

Write-Host "Calling the scheduling tool $PSScriptRoot\internal-scheduler.ps1..."
& "$PSScriptRoot\internal-scheduler.ps1" $groupNumber

Write-Host "Deleting old version of MS Office 2019 updates..."
Remove-Item -Recurse -Force "I:\Office2019InstallPoint\$groupNumber"
Write-Host "Copying new MS Office 2019 updates..."
Copy-Item -Path "D:\Applications\Office2019\ODT\Office" `
            -Destination "I:\Office2019InstallPoint\$groupNumber\Office" `
            -Recurse