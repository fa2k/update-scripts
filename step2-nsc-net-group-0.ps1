Write-Host "Step 2 -- Updating patch group 0 (Test) hosts."
Write-Host ""
Write-Host "* WSUS updates are already applied in the download script."
Write-Host "* Manual actions required:"
Write-Host "  - Add new software (Chrome, etc) to the GPO called 'General software install - P0'. Note: This will"
Write-Host "    trigger installation immediately on computers that are rebooted or logged out."
Write-Host "  - TODO more?."
Write-Host "* This script will schedule a reboot, and a Symantec update and scan."
Write-Host ""

Write-Host "Make sure you are connected to the NSC network when running this script."
Write-Host ""
Write-Host "Press Ctrl-C to abort now if not connected to NSC network..."
Write-Host ""
pause


$ErrorActionPreference = "Stop"

Write-Host "Making sure the Hyper-V VM 'dc2' is started (it is not required for this script)."
Start-VM dc2

Write-Host "Copying Linux updates to /data/common/repo..."

#ssh root@192.168.1.69 /data/repo/to-local-repo.sh

Write-Host "Calling the scheduling tool..."
Write-Host "$PSScriptRoot\internal-scheduler.ps1"

& "$PSScriptRoot\internal-scheduler.ps1" 0
