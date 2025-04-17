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

$SQL_postInstallActivity = @()
$SQL_postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName 'SQL-Enable NP and TCP.ps1' -DependencyFolder $global:labSources/PostinstallationActivities/SqlServer2022

# Windows Feature sets for each machine type
## Web Servers
### These will have both IIS installed and the ADUC tools, etc. These will be the 'admin boxes' of the lab.
$WF_Web = @( 'Web-Server', 
    'RSAT-AD-Tools', 
    'RSAT-AD-Powershell',
    'RSAT-ADDS-Tools',
    'RSAT-DNS-Server',
    'RSAT-ADCS',
    'RSAT-ADCS-Mgmt'
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
                -Role $role_DC, CaRoot `
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
            # $params = @{
            #     Name = $svr.Name
            #     Network = $LabName
            #     DomainName = $svr.Value.domain
            #     IpAddress = $svr.Value.ipaddress
            #     OperatingSystem = if ( $svr.Contains('os') ) { $svr.Values.os } else { 'Windows Server 2022 Standard (Desktop Experience)' }
            #     Gateway = ('{0}1' -f $LabSubnetStub) 
            # }
            # Add-LabMachineDefinition @params
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


# Install Everything
Install-Lab

# Install IIS and whatnot on Web servers
if ( (Get-LabMachines -Role web).Count -gt 0 ) {
    Install-LabWindowsFeature -ComputerName (Get-LabMachines web) -IncludeManagementTools -FeatureName $WF_Web 
}

# RabbitMQ Servers
if ((Get-LabMachines -Role "rmq") -gt 0 ) {
    $dl_path = "$global:labsources\SoftwarePackages\RMQ"

    if ( -not (Test-Path $dl_path) ) {
        mkdir $dl_path
    }

    $rmq_packages = @(
        'https://download.visualstudio.microsoft.com/download/pr/27bcdd70-ce64-4049-ba24-2b14f9267729/d4a435e55182ce5424a7204c2cf2b3ea/windowsdesktop-runtime-8.0.11-win-x64.exe',
        'https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.4/dotnet-hosting-9.0.4-win.exe',
        'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi',
        'https://downloads.marketplace.delinea.com/integrations/Downloads/RabbitMQ/latest/Delinea.RabbitMq.Helper.zip'
    )

    foreach ($pkg in $rmq_packages) {
        Get-LabInternetFile -Path $global:labSources\SoftwarePackages\RMQ\ -Uri $pkg
    }

    $packs = @()
    $packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\dotnet-hosting-9.0.4-win.exe -CommandLine "/install /quiet /norestart"
    $packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\windowsdesktop-runtime-8.0.11-win-x64.exe -CommandLine "/install /quiet /norestart"
    $packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\PowerShell-7.4.6-win-x64.msi -CommandLine "/quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1"

    Install-LabSoftwarePackages -Machine (Get-LabMachines -Role rmq | Get-LabVM) -SoftwarePackage $packs

    # Install Delinea RabbitMQ Helper
    Copy-LabFileItem -Path $global:labSources\SoftwarePackages\RMQ\Delinea.RabbitMq.Helper.zip -ComputerName (Get-LabMachines -Role rmq) -DestinationFolderPath C:\Temp\RMQ\
    Invoke-LabCommand -ActivityName "RMQ - Install Delinea RabbitMQ Helper" -ComputerName (Get-LabMachines -Role rmq) -ScriptBlock { 
        Expand-Archive -Path c:\temp\rmq\Delinea.RabbitMq.Helper.zip -DestinationPath c:\Temp\rmq -Force
        $file = Get-ChildItem C:\temp\rmq\delinea.rabbitmq.helper.*\Delinea.RabbitMQ.Helper.*.msi
        Start-Process -Wait -FilePath "msiexec" -ArgumentList @("/i", $file.fullname, "/l*v", "C:\temp\rmq\rmq-helper-install.log", "/quiet")
    }

    Copy-LabFileItem -Path $global:labSources\SoftwarePackages\RMQ\Setup-Erlang-RMQ-Helper.ps1 -ComputerName (Get-LabMachines -Role rmq) -DestinationFolderPath C:\Temp\RMQ\
    Invoke-LabCommand -ActivityName "RMQ - Install Erlang and RMQ" -ComputerName (Get-LabMachines -Role rmq)  -ScriptBlock {
        & "C:\Program Files\PowerShell\7\pwsh.exe" -Command C:\Temp\RMQ\Setup-Erlang-RMQ-Helper.ps1
    }
}

Show-LabDeploymentSummary