[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $Config = ".\config.psd1"
)

$ALConfig = Import-PowerShellDataFile -Path $Config

New-LabDefinition -Name $ALconfig.LabName -DefaultVirtualizationEngine HyperV

Set-LabInstallationCredential `
    -Username $ALConfig.Domain.AdminUser `
    -Password $ALConfig.Domain.AdminPassword

foreach ( $net in $ALConfig.Networking ) {
    Add-LabVirtualNetworkDefinition @net
}

# Only supports one Domain at the moment (sorry!)
$dom_splat = $ALConfig.Domain
Add-LabDomainDefinition @dom_splat


foreach ( $iso in $ALConfig.ISOs ) {
    Add-LabIsoImageDefinition @iso
}

foreach ( $vm in $ALConfig.VMs ) {
    $vm_splat = $ALConfig.VMDefaults.Clone()
    foreach ( $key in $vm.Keys ) {
        if ($vm_splat.ContainsKey($key)) {
            $vm_splat.$key = $vm.$key
        } else {
            $vm_splat.Add($key, $vm.$key)
        }
    }
    $netadapters = @()
    if ( $vm_splat.ContainsKey("NetworkAdapter") ) {
        foreach ( $net in $vm_splat.NetworkAdapter ) {
            $netadapters += New-LabNetworkAdapterDefinition @net
        }
        $vm_splat.NetworkAdapter = $netadapters
    }
    $roles = @()
    if ( $vm_splat.ContainsKey("Roles") ) {
        foreach ( $role in $vm_splat.Roles ) {
            if ( $role.ContainsKey("CustomRole") ) {
                $roles += Get-LabPostInstallationActivity @role 
            } elseif ( $role.ContainsKey("Role") ) {
                $roles += Get-LabMachineRoleDefinition @role
            }
        }
        $vm_splat.Roles = $roles
    }
    $pias = @()
    $pia_vars = @()
    if ($vm_splat.ContainsKey("PostInstallationActivity")) {
        foreach ( $pia in $vm_splat.PostInstallationActivity ) {
            if ( $pia.ContainsKey("Variable") ) {
                $pia.Variable | ForEach-Object {
                    $pia_vars += Get-Variable -Name $_
                }
                $pia.Variable = $pia_vars
            }
            $pia | Export-Clixml -Path C:\var.xml
            $pias += Get-LabPostInstallationActivity @pia
        }
        $vm_splat.PostInstallationActivity = $pias
    }
    Add-LabMachineDefinition @vm_splat
}

Install-Lab