
# Prerequisites:

# Create a GPO called "Update scheduling - P0" with update schedule, as described in the wiki.
# The new GPO should not be linked anywhere.

# GPOs for WSUS targeting and General software install should not exist.

# For this reason, the script is only relevant once at the initial configuration of the update
# scripts, and exists now as documentation of the required settings.

$ErrorActionPreference = "Stop"

function Set-PatchGroupPermissions {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Target,
        $PatchGroupName
    )
    PROCESS {
        $Target | `                Set-GPPermission -TargetType Group -TargetName "Authenticated Users" -PermissionLevel None | `
                Set-GPPermission -TargetType Group -TargetName $PatchGroupName -PermissionLevel GpoApply
    }
}

Copy-GPO -SourceName "Update scheduling - P0" -TargetName "Update scheduling - P1" | Out-Null
Copy-GPO -SourceName "Update scheduling - P0" -TargetName "Update scheduling - P2" | Out-Null
@(0, 1, 2) | ForEach-Object {
    $gpo = Get-GPO -Name "Update scheduling - P$_"
    $gpo | Set-PatchGroupPermissions -PatchGroupName "PatchGroup$_"
    $gpo | New-GPLink -Target "OU=LIMS,OU=Nsc_computers,DC=nscamg,DC=local"
    $gpo | New-GPLink -Target "OU=MTU,OU=Nsc_computers,DC=nscamg,DC=local"
    $gpo | New-GPLink -Target "OU=Servers,OU=Nsc_computers,DC=nscamg,DC=local"
}


ForEach ($group in @(0, 1, 2)) {
    ForEach ($class in @("All", "SecOnly")) {
        New-GPO -Name "WSUS targeting - P$group - $class" | `
            Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" `                -ValueName "TargetGroupEnabled" -Type DWORD -Value 1 | `
            Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" `
                -ValueName "TargetGroup" -Type String -Value "PatchGroup$group-$class" | `
            Set-PatchGroupPermissions -PatchGroupName "PatchGroup$group"
    }
}

@(0, 1, 2) | ForEach-Object {   
    New-GPLink -Name "WSUS targeting - P$_ - SecOnly" -Target "OU=Illumina,OU=Nsc_computers,DC=nscamg,DC=local"
    New-GPLink -Name "WSUS targeting - P$_ - SecOnly" -Target "OU=MTU,OU=Nsc_computers,DC=nscamg,DC=local"
    New-GPLink -Name "WSUS targeting - P$_ - All" -Target "OU=LIMS,OU=Nsc_computers,DC=nscamg,DC=local"
    New-GPLink -Name "WSUS targeting - P$_ - All" -Target "OU=Servers,OU=Nsc_computers,DC=nscamg,DC=local"
}

ForEach ($group in @(0, 1, 2)) {
    $gpo = New-GPO -Name "General software install - P$group"
    $gpo | New-GPLink -Target "OU=LIMS,OU=Nsc_computers,DC=nscamg,DC=local"
    $gpo | New-GPLink -Target "OU=With LIMS PC software,OU=64 bit,OU=MTU,OU=Nsc_computers,DC=nscamg,DC=local"
    $gpo | New-GPLink -Target "OU=Servers,OU=Nsc_computers,DC=nscamg,DC=local"
    $gpo | Set-PatchGroupPermissions -PatchGroupName "PatchGroup$group"
}
