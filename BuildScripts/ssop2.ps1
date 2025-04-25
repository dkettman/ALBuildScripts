# Import config.json
## Was going to use JSON for config, but discrepancies between how PowerShell 5 and PowerShell 7 handle the JSON conversion led to using YAML
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

# Windows Feature sets for each machine type
## Web Servers
### These will have both IIS installed and the ADUC tools, etc. These will be the 'admin boxes' of the lab.
$WF_Web = @( 
    'NET-Framework-45-ASPNET',
    'NET-WCF-HTTP-Activation45',
    'NET-WCF-TCP-Activation45',
    'NET-WCF-TCP-PortSharing45',
    'RSAT-AD-Powershell',
    'RSAT-AD-Tools', 
    'RSAT-ADCS',
    'RSAT-ADCS-Mgmt'
    'RSAT-ADDS-Tools',
    'RSAT-DNS-Server',
    'WAS',
    'WAS-Config-APIs',
    'WAS-Process-Model',
    'Web-AppInit',
    'Web-ASP-Net45',
    'Web-Dyn-Compression',
    'Web-Http-Redirect',
    'Web-ISAPI-Ext',
    'Web-ISAPI-Filter',
    'Web-Net-Ext45',
    'Web-Scripting-Tools',
    'Web-Server',
    'Web-Windows-Auth'
)

