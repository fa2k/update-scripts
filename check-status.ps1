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

foreach ($group in $PatchGroups) {
    Write-Host ""
	Write-Host "**** Patch group $group status *****"
    Write-Host ""
    
    $Array = @()

    $AdComputers = $PatchGroupMembers[$group] | Get-ADComputer
    $WsusGroupMembers = Get-WsusComputer -ComputerTargetGroups "PatchGroup$group-SecOnly","PatchGroup$group-All"
    
    foreach ($computer in $AdComputers) {
        $Result = $Computer | Select Name,WsusLastReport,LastBackup

        # Get WSUS status
        $WsusComp = $WsusGroupMembers | Where-Object { $_.FullDomainName -like $Computer.Name -or $_.FullDomainName -like "$($computer.Name).nscamg.local"}
        if (($WsusComp | measure).Count -eq 1) {
            $Result.WsusLastReport = $WsusComp.LastReportedStatusTime
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