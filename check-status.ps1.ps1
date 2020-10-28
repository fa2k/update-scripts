Write-Host "Check install status."

$ErrorActionPreference = "Stop"
$AllComputers = Get-ADComputer -Filter "*"

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
    Write-Host "The following computers are not in any PatchGroup[012] or NoPatchGroup:"
    $UnknownComputers | Select-Object -Property Name
    Write-Host "This is an error. Please fix and then re-run the script."
    exit
}

foreach ($group in $PatchGroups) {
	Write-Host "Patch group $group status"
    
}