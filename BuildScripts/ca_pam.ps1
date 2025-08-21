[CmdletBinding()]
param (
    [Parameter()]
    [string]$config_file = ".\config.json"
)

# First, make sure we are running in PS7 and not PS5
if ($PSVersionTable.PSVersion -lt 7) {
    Write-Error "Must use PowerShell 7!"
}

# Import config.json
$config = Get-Content $config_file -Raw | ConvertFrom-JSON -AsHashtable

# Setup some basic variables we will use throughout the script
$LabSubnetStub = ($config.network_info.lab_subnet | Select-String -Pattern '(\d{1,3}\.\d{1,3}\.\d{1,3}\.)\d{1,3}\/\d{1,2}').Matches.Groups[1].Value
$Domain_DN = 'DC=' + $config.domain_info.domain_name.Replace('.', ',DC=')

## Functions ##
function Get-LabMachines {
    param (
        [String]
        $Role,
        [SwitchParameter]
        $First = $false
    )
    $result = ($config.svrs.values | Where-Object { $_.Role -eq $Role }).NodeName
    if ($First) {
        if ( $result.count -eq 1 ) {
            return $result
        }
        else {
            return $result[0]
        }
    }
    else {
        return $return
    }

}

# Setup our Lab and define the Network and Domain
New-LabDefinition -Name $config.lab_name -DefaultVirtualizationEngine HyperV
Add-LabVirtualNetworkDefinition -Name $config.lab_name -AddressSpace $LabSubnet
Add-LabDomainDefinition -Name $config.domain_info.domain_name -AdminUser $config.admin_username -AdminPassword $config.admin_password
Set-LabInstallationCredential -Username $config.admin_username -Password $config.admin_password

# Adding the SQL2022 ISO to our list of ISOs we are aware of
Add-LabIsoImageDefinition -Name SQLServer2022 -Path F:\LabSources\ISOs\SQLServer2022-x64-ENU-Dev.iso

# Defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'         = $config.lab_name
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:DomainName'      = $config.domain_info.domain_name
    'Add-LabMachineDefinition:DnsServer1'      = ($LabSubnetStub + '10')
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Standard (Desktop Experience)'
    'Add-LabMachineDefinition:Gateway'         = '{0}1' -f $LabSubnetStub
    'Add-LabMachineDefinition:Memory'          = 512MB
    'Add-LabMachineDefinition:Processors'      = 2
}

# Modify roles as needed for each machine type
## Domain Controller (Role: RootDC)
$role_DC = Get-LabMachineRoleDefinition -Role RootDC @{
    SiteName   = 'Kalamazoo'
    SiteSubnet = $config.network_info.lab_subnet
}

## SQLServer 2022 (Role: SqlServer2022)
$role_SQL2022 = Get-LabMachineRoleDefinition -Role SQLServer2022 @{
    Features       = 'SQL,Tools'
    SQLSvcAccount  = $config.SQL.sqlsvcaccount
    SQLSvcPassword = $config.SQL.sqlsvcpassword
}

# Add Lab Machine Definitions
## This loops over our Server definitions in the configuration file to add each machine's definition to the lab.
$config.svrs.GetEnumerator() | ForEach-Object {
    $svr = $_
    # Need to do some shenanigans to get custom roles and PIAs to work. I'm sure it's messy, but it's home...
    $roles = @()
    foreach ( $r in $svr.Value.Roles ) { 
        if ( $r.StartsWith('$') ) {
            $roles += Invoke-Expression $r
        }
        else {
            $roles += Get-LabMachineRoleDefinition $r
        }
    }
    # $pia = @()
    # foreach ( $pia in $svr.Value.PIA ) {
    #     $pia += (Get-LabPostInstallationActivity -CustomRole $pia)
    #     # $pia += Invoke-Expression $pia
    # }

    $pia = Get-LabPostInstallationActivity -CustomRole $svr.Value.PIA[0]

    # Splat with all required options for each machine
    $params = @{
        Name                     = $svr.Key
        Network                  = $config.lab_name
        DomainName               = ($svr.Value.Domain ?? $config.domain_info.domain_name)
        Role                     = $roles
        OperatingSystem          = ($svr.Value.OS ?? 'Windows Server 2022 Standard (Desktop Experience)')
        IpAddress                = $svr.Value.IP
        Gateway                  = ('{0}1' -f $LabSubnetStub)
        DnsServer1               = ($LabSubnetStub + '10')
        PostInstallationActivity = $pia
    }

    # Additional Config Checks
    ## Check for Memory
    if ($null -ne $svr.Value.Memory) { $params += @{ Memory = $svr.Value.Memory } }

    ## Check for Processors
    if ($null -ne $svr.Value.Processors) { $params += @{ Processors = $svr.Value.Processors } }

    Add-LabMachineDefinition @params


}

# Install and configure the network (If needed)
Write-ScreenInfo -Type Info -TaskStart -Message "NAT - VM Switch NAT Setup"

$net_nats = Get-NetNat
$nat_err_cnt = 0

if ( $net_nats.Count -gt 0 ) {
    Write-ScreenInfo -Type Warning -Message (("Found an existing NAT! Checking to make sure it is valid"))
    if ( $net_nats[0].Name -eq $config.lab_name ) {
        Write-ScreenInfo -Type Verbose -Message (("Current NAT has correct name ({0}).") -f $config.lab_name)
    }
    else {
        Write-ScreenInfo -Type Error -Message (("Current NAT has an incorrect name (Is: {0}, should be: {1})." ) -f $net_nats[0].Name, $config.lab_name )
        $nat_err_cnt++
    }

    if ( $net_nats[0].InternalIPInterfaceAddressPrefix -eq $config.network_info.lab_subnet ) {
        Write-ScreenInfo -Type Verbose -Message (("Current NAT has correct subnet ({0}).") -f $LabSubnet)
    }
    else {
        Write-ScreenInfo -Type Error -Message (("Current NAT has an incorrect Subnet (Is: {0}, should be: {1})." ) -f $net_nats[0].InternalIPInterfaceAddressPrefix, $config.network_info.lab_subnet )
        $nat_err_cnt++
    }

}
elseif (( $net_nats.Count -eq 0 ) -and ( $nat_err_cnt -eq 0 )) {
    Write-ScreenInfo -Type Info -Message (("NAT did not exist! Creating..."))
    New-NetNat -Name $config.lab_name -InternalIPInterfaceAddressPrefix $config.network_info.lab_subnet | Out-Null
}
elseif ( $nat_err_cnt -gt 0 ) {
    Write-ScreenInfo -Type Error -Message (("Something went wrong. Please check NAT configuration and try again."))
}
else {
    Write-ScreenInfo -Type Warning -Message (("Existing NAT ({0}) is correct and current!") -f $net_nats[0].Name )
}
Write-ScreenInfo -Type Info -TaskEnd -Message "NAT - VM Switch NAT Setup Complete"

# Network is setup! Show time!

# $config.GetEnumerator() | Foreach-Object {
#     $_ | Foreach-Object {
#         $_
#     }
# }

# Install Everything
# Install-Lab

# At this point, what *should* be done is:
# - All machines built
# - Network setup
# - Active Directory Domain setup
# - Certificate Authority setup
# - SQL2022 installed (if applicable)
#   - Enabled Named Pipes and TCP connections
# - IIS installed (if applicable)
# - SSL Certificate created and installed

# Draw the rest of the f*cking owl
# Write-ScreenInfo -Type Info -TaskStart -Message "Setting up AD Objects"
# # Create AD Infrastructure and service accounts
# ## Lets start with OUs
# Invoke-LabCommand `
#     -ActivityName "Creating AD OUs" `
#     -ComputerName ((Get-LabMachines -role dc | Select-Object -First 1)) `
#     -ArgumentList $config.activedirectory.OUs `
#     -ScriptBlock {
#         foreach ( $ou in $args[0] ) {
#             New-ADOrganizationalUnit -Name $ou
#         }
#     }
# Write-ScreenInfo -Type Info -TaskEnd -Message "AD OUs Created"

# Checkpoint-LabVM -SnapshotName "Fresh Build" -All
# Show-LabDeploymentSummary