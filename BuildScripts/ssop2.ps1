# Import config.json
## Was going to use JSON for config, but discrepancies between how PowerShell 5 and PowerShell 7 handle the JSON conversion led to using YAML
$config = Get-Content config.json -Raw | ConvertFrom-Json -AsHashtable


$LabName = $config.lab_name
$LabSubnet = $config.network_info.lab_subnet
$LabSubnetStub = ($LabSubnet | Select-String -Pattern '(\d{1,3}\.\d{1,3}\.\d{1,3}\.)\d{1,3}\/\d{1,2}').Matches.Groups[1].Value

## Functions ##
function Get-LabVMIP {
    param (
        $Role,
        $Hostname
    )
    $LabSubnetStub + [string]( [int]($config.network_info.role_ips.$Role) + [int]($Hostname | Select-String -Pattern '.*(\d)').Matches.Groups[1].Value )    
}

function Get-LabMachines {
    param (
        $Role
    )

    (($config.svrs.GetEnumerator() | Where-Object { $_.Value.role -eq $Role }).Name)

}

foreach ($s in $config.svrs.Keys) {
    $config.svrs.$s.ipaddress = Get-LabVMIP $config.svrs.$s.role $s
}

New-LabDefinition -Name $LabName -DefaultVirtualizationEngine HyperV

Add-LabVirtualNetworkDefinition -Name $LabName -AddressSpace $LabSubnet

Add-LabDomainDefinition -Name $config.domain_info.domain_name -AdminUser $config.admin_username -AdminPassword $config.admin_password

$Domain_DN = 'DC='+$config.domain_info.domain_name.Replace('.',',DC=')

Add-LabIsoImageDefinition -Name SQLServer2022 -Path F:\LabSources\ISOs\SQLServer2022-x64-ENU-Dev.iso

Set-LabInstallationCredential -Username $config.admin_username -Password $config.admin_password

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'         = $labName
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:DomainName'      = $config.domain_info.domain_name
    'Add-LabMachineDefinition:DnsServer1'      = Get-LabVMIP dc ('{0}-dc01' -f $LabName)
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Standard (Desktop Experience)'
    'Add-LabMachineDefinition:Gateway'         = '{0}1' -f $LabSubnetStub
}

# Modify roles as needed for each machine type
## Domain Controller (Role: RootDC)
$role_DC = Get-LabMachineRoleDefinition -Role RootDC @{
    SiteName   = 'Kalamazoo'
    SiteSubnet = $LabSubnet
}

## SQLServer 2022 (Role: SqlServer2022)
$role_SQL2022 = Get-LabMachineRoleDefinition -Role SQLServer2022 @{
    Features       = 'SQL,Tools'
    SQLSvcAccount  = $config.sql.sqlsvcaccount
    SQLSvcPassword = $config.sql.sqlsvcpassword
}

$SQL2022_postInstallActivity = @()
$SQL2022_postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName 'SQL-Enable NP and TCP.ps1' -DependencyFolder $global:labSources/PostinstallationActivities/SqlServer2022

## Web Server (Role: Delinea_SSOP_Web)
$role_Delinea_SSOP_Web = Get-LabPostInstallationActivity -CustomRole Delinea_SSOP_Web -Properties @{ 
                                    DomainName = $config.domain_info.domain_name
                                    AppPoolUsername = "svc_vault_iis"
                                    AppPoolPassword = $config.admin_password }

$role_Delinea_SSOP_RMQ = Get-LabPostInstallationActivity -CustomRole Delinea-SSOP-RMQ 

$config.svrs.GetEnumerator() | ForEach-Object {
    $svr = $_
    switch ($_.Value.role) {
        "dc" {
            Add-LabMachineDefinition `
                -Name $svr.Name `
                -Network $LabName `
                -DomainName $svr.Value.domain `
                -IpAddress $svr.Value.ipaddress `
                -Role $role_DC, CaRoot `
                -OperatingSystem 'Windows Server 2022 Standard' `
                -Gateway ('{0}1' -f $LabSubnetStub)
            break
        }
        "rmq" {
            Add-LabMachineDefinition `
                -Name $svr.Name `
                -Network $LabName `
                -DomainName $svr.Value.domain `
                -IpAddress $svr.Value.ipaddress `
                -OperatingSystem 'Windows Server 2022 Standard (Desktop Experience)' `
                -Gateway ('{0}1' -f $LabSubnetStub) `
                -PostInstallationActivity $role_Delinea_SSOP_RMQ
            break
        }
        "sql" {
            Add-LabMachineDefinition `
                -Name $svr.Name `
                -Network $LabName `
                -DomainName $svr.Value.domain `
                -IpAddress $svr.Value.ipaddress `
                -Role $role_SQL2022 `
                -OperatingSystem 'Windows Server 2022 Standard' `
                -Gateway ('{0}1' -f $LabSubnetStub) `
                -PostInstallationActivity $SQL2022_postInstallActivity
            break
        }
        "web" {
            Add-LabMachineDefinition `
                -Name $svr.Name `
                -Network $LabName `
                -DomainName $svr.Value.domain `
                -IpAddress $svr.Value.ipaddress `
                -OperatingSystem 'Windows Server 2022 Standard (Desktop Experience)' `
                -Gateway ('{0}1' -f $LabSubnetStub) `
                -PostInstallationActivity $role_Delinea_SSOP_web
            break
        }
        default {
            Add-LabMachineDefinition `
                -Name $svr.Name `
                -Network $LabName `
                -DomainName $svr.Value.domain `
                -IpAddress $svr.Value.ipaddress `
                -OperatingSystem 'Windows Server 2022 Standard (Desktop Experience)' `
                -Gateway ('{0}1' -f $LabSubnetStub)
            break
        }
    }
}

# Install and configure the network (If needed)
Write-ScreenInfo -Type Info -TaskStart -Message "NAT - VM Switch NAT Setup"

$net_nats = Get-NetNat
$nat_err_cnt = 0

if ( $net_nats.Count -gt 0 ) {
    Write-ScreenInfo -Type Warning -Message (("Found an existing NAT! Checking to make sure it is valid"))
    if ( $net_nats[0].Name -eq $LabName ) {
        Write-ScreenInfo -Type Verbose -Message (("Current NAT has correct name ({0}).") -f $LabName)
    }
    else {
        Write-ScreenInfo -Type Error -Message (("Current NAT has an incorrect name (Is: {0}, should be: {1})." ) -f $net_nats[0].Name, $LabName )
        $nat_err_cnt++
    }

    if ( $net_nats[0].InternalIPInterfaceAddressPrefix -eq $LabSubnet ) {
        Write-ScreenInfo -Type Verbose -Message (("Current NAT has correct subnet ({0}).") -f $LabSubnet)
    }
    else {
        Write-ScreenInfo -Type Error -Message (("Current NAT has an incorrect Subnet (Is: {0}, should be: {1})." ) -f $net_nats[0].InternalIPInterfaceAddressPrefix, $LabSubnet )
        $nat_err_cnt++
    }

}
elseif (( $net_nats.Count -eq 0 ) -and ( $nat_err_cnt -eq 0 )) {
    Write-ScreenInfo -Type Info -Message (("NAT did not exist! Creating..."))
    New-NetNat -Name $LabName -InternalIPInterfaceAddressPrefix $LabSubnet | Out-Null
}
elseif ( $nat_err_cnt -gt 0 ) {
    Write-ScreenInfo -Type Error -Message (("Something went wrong. Please check NAT configuration and try again."))
}
else {
    Write-ScreenInfo -Type Warning -Message (("Existing NAT ({0}) is correct and current!") -f $net_nats[0].Name )
}
Write-ScreenInfo -Type Info -TaskEnd -Message "NAT - VM Switch NAT Setup Complete"
