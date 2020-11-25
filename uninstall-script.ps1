
$ErrorActionPreference = "Continue"

ForEach ($group in @(0, 1, 2)) {
    ForEach ($class in @("All", "SecOnly")) {
        Remove-GPO -Name "WSUS targeting - P$group - $class"
    }
    Remove-GPO -Name "General software install - P$group"
}

Remove-GPO -Name "Update scheduling - P1"
Remove-GPO -Name "Update scheduling - P2"
Write-Host "TODO remove manually GPO: Update scheduling - P0"
Remove-GPLink -Name "Update scheduling - P0" -Target "OU=LIMS,OU=Nsc_computers,DC=nscamg,DC=local"
Remove-GPLink -Name "Update scheduling - P0" -Target "OU=MTU,OU=Nsc_computers,DC=nscamg,DC=local"
Remove-GPLink -Name "Update scheduling - P0" -Target "OU=Servers,OU=Nsc_computers,DC=nscamg,DC=local"