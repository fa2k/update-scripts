Write-Host "Step 2 -- Updating patch group."
Write-Host "Note: First check the status of previous group (0 or 1) using check-status.ps1 and manual methods."
Write-Host ""
$ErrorActionPreference = "Stop"

$groupNumber = Read-Host -Prompt "Enter the group number to update, 1 or 2: "


Write-Host ""

$sourceGpoName = "General software install - P0"
$gpoName = "General software install - P$groupNumber"

Write-Host "Backing up settings from '$sourceGpoName'..."
$backup = Backup-GPO -Name $sourceGpoName -Path C:\TEMP
Write-Host "Importing settings into '$gpoName'..."
$targetGpo = Get-GPO -Name $gpoName
$targetGpo.Import($backup) | Out-Null


$TargetMembers = Get-ADGroupMember -Identity PatchGroup0

$secCritUpdates = Get-WsusUpdate -Classification Security -Approval Unapproved

#$license = $updates | Where {$_.RequiresLicenseAgreementAcceptance}
#$license | Select Title
#$license | ForEach {$_.AcceptLicenseAgreement()}

Write-Host "Approving security updates for PatchGroup0-SecOnly..."
$updates = Get-WsusUpdate -Approval Unapproved
 kkecktodo | `
        Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup0-SecOnly
Get-WsusUpdate -Classification Critical -Approval Unapproved | `
        Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup0-SecOnly


Get-WsusUpdate -Approval Unapproved | `
        Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup0-All

Write-Host "Run the Cleanup Tool"
Get-WsusServer | 
    Invoke-WsusserverCleanup -CleanupObsoleteUpdates `
             -CleanupUnneededContentFiles -CompressUpdates `
             -DeclineExpiredUpdates -DeclineSupersededUpdates
