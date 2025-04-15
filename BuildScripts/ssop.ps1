# Import config.json

#$config = Get-Content config.json | ConvertFrom-Json -AsHashtable
$config = Get-Content config.yaml -Raw | ConvertFrom-Yaml

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
    Features = 'SQL,Tools'
    SQLSvcAccount  = $config.sql.sqlsvcaccount
    SQLSvcPassword = $config.sql.sqlsvcpassword
}

$SQL_postInstallActivity = @()
$SQL_postInstallActivity += Get-LabPostInstallationActivity -Name "SQL - Enable Named Pipes and TCP Ports" -ScriptFileName 'SQL-Enable NP and TCP.ps1' -DependencyFolder $global:labSources/PostinstallationActivities/SqlServer2022

# Windows Feature sets for each machine type
## Web Servers
### These will have both IIS installed and the ADUC tools, etc. These will be the 'admin boxes' of the lab.
$WF_Web = @( 'Web-Server', 
    'RSAT-AD-Tools', 
    'RSAT-AD-Powershell',
    'RSAT-ADDS-Tools',
    'RSAT-DNS-Server'
)

# Add Lab Machine Definitions
$config.svrs.GetEnumerator() | ForEach-Object {
    $svr = $_
    switch ($_.Value.role) {
        "dc" {
            Add-LabMachineDefinition `
                -Name $svr.Name `
                -Network $LabName `
                -DomainName $svr.Value.domain `
                -IpAddress $svr.Value.ipaddress `
                -Role $role_DC `
                -OperatingSystem 'Windows Server 2022 Standard' `
                -Gateway ('{0}1' -f $LabSubnetStub) `
                #-Memory $svr.Value.memory `
                #-Processors $svr.Value.cpu
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
                -PostInstallationActivity $SQL_postInstallActivity
                #-Memory $svr.Value.memory `
                #-Processors $svr.Value.cpu
            break
        }
        default {
            Add-LabMachineDefinition `
                -Name $svr.Name `
                -Network $LabName `
                -DomainName $svr.Value.domain `
                -IpAddress $svr.Value.ipaddress `
                -OperatingSystem 'Windows Server 2022 Standard (Desktop Experience)' `
                -Gateway ('{0}1' -f $LabSubnetStub) `
                #-Memory $svr.Value.memory `
                #-Processors $svr.Value.cpu
        }
    }
}

# Install and configure the network
Install-Lab -NetworkSwitches
New-NetNat -Name $LabName -InternalIPInterfaceAddressPrefix $LabSubnet

# Install Everything else
Install-Lab

# Install IIS and whatnot on Web servers
Install-LabWindowsFeature -ComputerName (Get-LabMachines web) -IncludeManagementTools -FeatureName $WF_Web 

Show-LabDeploymentSummary