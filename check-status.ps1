Write-Host "Checking install status..."

$ErrorActionPreference = "Stop"
$AllComputers = Get-ADComputer -Filter "*"

$BackupUncPath = "\\endpoint\NSC\Test"

$PatchGroups = 0, 1, 2
$PatchGroupMembers =      (Get-ADGroupMember -Identity PatchGroup0),
                          (Get-ADGroupMember -Identity PatchGroup1),
                          (Get-ADGroupMember -Identity PatchGroup2)

$NoPatchComputers = Get-ADGroupMember -Identity NoPatchGroup



# Checking that all computers are in one of these groups
$KnownComputersSids = ($PatchGroupMembers | ForEach-Object { $_ }) + $NoPatchComputers | ForEach-Object { $_.SID }
$UnknownComputers = $AllComputers | Where-Object SID -NotIn $KnownComputersSids
if ($UnknownComputers)
{
    Write-Warning "The following computers are not in any PatchGroup[012] or NoPatchGroup:"
    $UnknownComputers | Select-Object -Property Name
    Write-Error "This is an error. Please fix and then re-run the script."
}

Write-Host "Getting new cumulative updates from updatelist file..."
if (Test-Path D:\updatelist.txt) {
    Get-Content -Path D:\updatelist.txt | `
                    Where-Object { $_ } | ` # Not empty string
                    ForEach-Object { Get-WsusUpdate -UpdateId $_ } | `
                    Where-Object { $_.Update.Title -match "^\d\d\d\d-\d\d Cumulative " } | `
                    Tee-Object -Variable NewCumUpdates
}
else {
    $NewCumUpdates = @()
}
if (-not $NewCumUpdates) {
    Write-Host "No updates matching the criteria were found. 'Installed' counts will be zero."
}

$TargetGroups = (Get-WsusServer).GetComputerTargetGroups()


foreach ($group in $PatchGroups) {
    Write-Host ""
	Write-Host "**** Patch group $group status *****"
    Write-Host ""
    
    $Array = @()

    $AdComputers = $PatchGroupMembers[$group] | Get-ADComputer
    $WsusGroupMembers = Get-WsusComputer -ComputerTargetGroups "PatchGroup$group-SecOnly","PatchGroup$group-All"
    $ThisTargetGroups = $TargetGroups | Where-Object { $_.Name -like "PatchGroup$group-*" }
    $CumlUpdateStatuses = $NewCumUpdates | `
                            ForEach-Object {
                                $update = $_
                                $ThisTargetGroups | ForEach-Object {
                                            $update.Update.GetUpdateInstallationInfoPerComputerTarget($_)
                                            
                                            }
                                }

    foreach ($computer in $AdComputers) {
        $Result = $Computer | Select Name,WsusLastReport,CumlInstCount,LastBackup

        # Get WSUS status
        $WsusComp = $WsusGroupMembers | Where-Object { $_.FullDomainName -like $Computer.Name -or $_.FullDomainName -like "$($computer.Name).nscamg.local"}
        if ($WsusComp.count -eq 1) {
            $Result.WsusLastReport = $WsusComp.LastReportedStatusTime
            $CumlPatchesInstalled = $CumlUpdateStatuses | `
                                        Where-Object { $_.ComputerTargetId -eq $WsusComp.Id -and `
                                                       $_.UpdateInstallationState -eq "Installed" }
            $Result.CumlInstCount = $CumlPatchesInstalled.count
                                        
        }
        else {
            Write-Warning "Computer '$($computer.Name)' is not in any WSUS target for patch group $group."
        }
        # Find last backup time
        $Result.LastBackup = (Get-ChildItem -Path $BackupUncPath -Filter "$($computer.Name)-*" | 
                                        Select-Object -Property LastWriteTime |
                                        Sort-Object |
                                        Select-Object -Last 1 |
                                        ForEach-Object {$_.LastWriteTime} )
        $Array += $Result

    }
    $Array | Format-Table
    
}