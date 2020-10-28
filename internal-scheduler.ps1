
$group = $args[0]
Write-Host ""
Write-Host "Will schedule the following events for hosts in patch group ${group}:"
Write-Host ""

$now = Get-Date
$forceRebootTime = $now.Date.AddHours(22)
Write-Host "Forced reboot at:      $forceRebootTime"
$updateDefinitionsTime = $now.Date.AddHours(22).AddMinutes(50)
Write-Host "Definitions update at: $updateDefinitionsTime"
$avScanTime = $now.Date.AddDays(1).AddHours(3)
Write-Host "Antivirus scan at:     $avScanTime"

Write-Host ""

Write-Host "Loading the GPO for scheduled tasks: $scheduledTaskGpo"

$backup = Backup-GPO ""

$xml = New-Object -TypeName XML
$xml.Load($Path)

# TODO COPYPAPSTAs	
Foreach ($item in (Select-XML -Xml $xml -XPath '//Machine'))
{
    $item.node.Name = 'Prod_' + $item.node.Name
}
 
$NewPath = "$env:temp\inventory2.xml"
$xml.Save($NewPath)
notepad $NewPath