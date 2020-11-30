# Update process -- Step 1 = download updates

$ErrorActionPreference = "Stop"
$DataDrive = "D:"

Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "------ Update procedure - step 1 ------"
Write-Host ""

Write-Host "This script syncs Windows and MS Office updates, and Linux update (yum packages),"
Write-Host "and approves them for the update group 0 -- testing hosts."
Write-Host ""
Write-Host "You can sync the other software manually:"

Write-Host ""
Write-Host ""
Write-Host "- Manual sync job #1: Symantec"
Write-Host "http://localhost:7070/lua/"
Write-Host ""
Write-Host ""
Write-Host "- Manual sync job #2 (optional): Google Chrome, Adobe Reader"
Write-Host "  Software in MSI format can be downloaded and transferred to Endpoint server"
Write-Host "  from any Internet-connected host. Then the software has to be added to the"
Write-Host "  Group Policy Object (GPO) called 'General software install - P0'"
Write-Host "https://chromeenterprise.google/browser/download/"
Write-Host ""

Write-Host ""
Write-Host ""
Write-Host "Make sure you are connected to the internet and disconnected from the NSC network."
Write-Host "Checking connection. Ping results:"
Test-Connection -Count 1 www.uio.no
Write-Host ""
Write-Host "Press Ctrl-C to abort now if not connected to the Internet (and re-run script later).."
Write-Host ""
pause

if (Test-Path $DataDrive\updatelist.txt)
{
    Write-Warning "UPDATE LIST FILE updatelist.txt EXISTS."
    Write-Host ""
    Write-Host "- If the updates have already been approved for all groups, then delete updatelist.txt."
    Write-Host "- If you are re-running this download script, but haven't deployed the updates from the"
    Write-Host "  previous run, then leave the file in place. It will be appended to."
    Write-Host ""
    pause
}

Write-Host "Triggering WSUS synchronization..."
$wsusServer = Get-WsusServer
$wsusSub = $wsusServer.GetSubScription()
$preSyncTime = (Get-Date).ToUniversalTime()
$wsusSub.StartSynchronization()
Write-Host ""
Write-Host ""

Write-Host "Downloading MS Office 2019 updates..."
Start-Process "$DataDrive\Applications\Office2019\ODT\nsc-dl-update-command.bat" `
        -WorkingDirectory "$DataDrive\Applications\Office2019\ODT\" `
        -NoNewWindow -Wait

Write-Host ""
Write-Host ""

Write-Host "Syncing Linux packages by running a command on the 'downloader' VM..."
#ssh root@192.168.1.69 /data/repo/sync-rpm.sh
Write-Host ""
Write-Host ""

Write-Host "Waiting for WSUS sync to finish..."
$wsusSub = $wsusServer.GetSubScription()
$wsusSync = $wsusSub.GetLastSynchronizationInfo()
while ($wsusSync.StartTime -le $preSyncTime) {
    Start-Sleep -Seconds 10
    $wsusSub = $wsusServer.GetSubScription()
    $wsusSync = $wsusSub.GetLastSynchronizationInfo()
}
Write-Host "WSUS sync result: $($wsusSync.Result)"
Write-Host ""

Write-Host "Getting a list of unapproved updates..."
$updates = Get-WsusUpdate -Approval Unapproved
Write-Host "Number of unapproved updates: $($updates.count)."

Write-Host "Decline language packs with languages other than Norwegian or English (UK/US)"
$updates  | 
        Where-Object {$_.Update.Title -like "*LanguagePack*" `
            -or $_.Update.Title -like "*LanguageFeatureOnDemand*" `
            -or $_.Update.Title -like "*LanguageInterfacePack*"} |
        Where-Object {$_.Update.Title -notlike "*``[nb-NO*" `
            -and $_.Update.Title -notlike "*``[en-US*" `
            -and $_.Update.Title -notlike "*``[en-GB*"} |
            Deny-WsusUpdate

Write-Host "Decline Windows 10 Editions which we don't have"
$updates |
        Where-Object {$_.Update.Title -like "*Windows 10 Enterprise*" `
                -or $_.Update.Title -like "*Windows 10 Education*" `
                -or $_.Update.Title -like "*Windows 10 Team*" } |
                Deny-WsusUpdate
                
Write-Host "Decline Preview updates"
$updates |
        Where-Object {$_.Update.Title -like "*Preview of *" } |
                Deny-WsusUpdate

Write-Host "Decline x86 (32-bit) and ARM updates"
$updates |
        Where-Object {$_.Update.Title -like "* for ARM64-based Systems*" } |
                Deny-WsusUpdate


Write-Host "Refresh update information and remove declined updates from list..."                
$updates = $updates | ForEach-Object { Get-WsusUpdate -UpdateId $_.UpdateId } | `
                                     Where-Object Approval -ne Declined

Write-Host "Writing a list of updates to updatelist.txt."
$updates | Select-Object -ExpandProperty UpdateId | `                Out-File -FilePath $DataDrive\updatelist.txt -Append

Write-Host "Accepting licenses if necessary..."
$license = $updates | Where-Object { $_.LicenseAgreement -ne "This update does not have Microsoft Software License Terms." }
$license | ForEach {$_.Update.AcceptLicenseAgreement()}


Write-Host "__________________________________________________"
Write-Host "Approving updates for Group 0 -- Necessary for"
Write-Host "downloading from WSUS."

Write-Host "Approving security updates for PatchGroup0-SecOnly..."
$updates | Where-Object Classification -eq Security | `
        Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup0-SecOnly
$updates | Where-Object Classification -eq Critical | `
        Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup0-SecOnly
        
Write-Host "Approving all updates for PatchGroup0-All..."
$updates | Approve-WsusUpdate -Action Install -TargetGroupName PatchGroup0-All


Write-Host "Runnig the WSUS Cleanup Tool..."
$wsusServer | 
    Invoke-WsusserverCleanup -CleanupObsoleteUpdates `
             -CleanupUnneededContentFiles -CompressUpdates `
             -DeclineExpiredUpdates -DeclineSupersededUpdates

$progress = $wsusServer.GetContentDownloadProgress()
Write-Host "Waiting for WSUS downloading to finish..."
while ($progress.DownloadedBytes -ne $progress.TotalBytesToDownload) {
    Start-Sleep -Seconds 60
    $progress = $wsusServer.GetContentDownloadProgress()
    Write-Host "Remaining: $(($progress.TotalBytesToDownload - $progress.DownloadedBytes)/1073741824) GB"
}

Write-Host "__________________________________________________"
Write-Host "Sync complete!"
Write-Host "After also completing the manual syncs, the server may be connected back to the NSC"
Write-Host "network and disconnected from the Internet."
Write-Host ""
