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
$Domain_DN = 'DC='+$config.domain_info.domain_name.Replace('.',',DC=')

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
        $Role,
        [SwitchParameter]
        $First=$false
    )
        $result = ($config.svrs.values | Where-Object { $_.Role -eq $Role}).NodeName
    if ($First) {
        if ( $result.count -eq 1 ) {
            return $result
        } else {
            return $result[0]
        }
    } else {
        return $return
    }

}

# Determining each VM's IP address based on their identifier and server role
foreach ($s in $config.svrs.Keys) {
    $config.svrs.$s.ipaddress = Get-LabVMIP $config.svrs.$s.Role $s
}

# Setup our Lab and define the Network and Domain
New-LabDefinition -Name $config.lab_name -DefaultVirtualizationEngine HyperV
Add-LabVirtualNetworkDefinition -Name $config.lab_name -AddressSpace $LabSubnet
Add-LabDomainDefinition -Name $config.domain_info.domain_name -AdminUser $config.domain_info.admin_username -AdminPassword $config.domain_info.admin_password
Set-LabInstallationCredential -Username $config.domain_info.admin_username -Password $config.domain_info.admin_password

# Adding the SQL2022 ISO to our list of ISOs we are aware of
Add-LabIsoImageDefinition -Name SQLServer2022 -Path F:\LabSources\ISOs\SQLServer2022-x64-ENU-Dev.iso

# Defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'         = $config.lab_name
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:DomainName'      = $config.domain_info.domain_name
    'Add-LabMachineDefinition:DnsServer1'      = Get-LabVMIP dc ('{0}-dc01' -f $config.lab_name)
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Standard (Desktop Experience)'
    'Add-LabMachineDefinition:Gateway'         = '{0}1' -f $LabSubnetStub
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
    switch ($_.Value.Role) {
        "dc" {
            Add-LabMachineDefinition `
                -Name $svr.Value.NodeName `
                -Network $config.lab_name `
                -DomainName ($svr.Value.Domain ?? $config.domain_info.domain_name) `
                -IpAddress $svr.Value.ipaddress `
                -Role $role_DC, CaRoot `
                -OperatingSystem 'Windows Server 2022 Standard' `
                -Gateway ('{0}1' -f $LabSubnetStub) `
                -DnsServer1 $svr.Value.ipaddress
                # -PostInstallationActivity $pia_Delinea_SSOP_DC
            break
        }
        "sql" {
            Add-LabMachineDefinition `
                -Name $svr.Value.NodeName `
                -Network $config.lab_name `
                -DomainName ($svr.Value.Domain ?? $config.domain_info.domain_name) `
                -IpAddress $svr.Value.ipaddress `
                -Role $role_SQL2022 `
                -OperatingSystem 'Windows Server 2022 Standard' `
                -Gateway ('{0}1' -f $LabSubnetStub) `
                -DnsServer1 ('{0}11' -f $LabSubnetStub) `
                -Memory $svr.Value.Memory `
                -Processors $svr.Value.CPU
            break
        }
        "web" {
            Add-LabMachineDefinition `
                -Name $svr.Value.NodeName `
                -Network $config.lab_name `
                -DomainName ($svr.Value.Domain ?? $config.domain_info.domain_name) `
                -IpAddress $svr.Value.ipaddress `
                -OperatingSystem 'Windows Server 2022 Standard (Desktop Experience)' `
                -Gateway ('{0}1' -f $LabSubnetStub) `
                -DnsServer1 ('{0}11' -f $LabSubnetStub) `
                -PostInstallationActivity $role_Delinea_SSOP_web
            break
        }
        # If the role isn't defined, just create a Win2022 Desktop Server
        default {
            Add-LabMachineDefinition `
                -Name $svr.Value.NodeName `
                -Network $config.lab_name `
                -DomainName ($svr.Value.Domain ?? $config.domain_info.domain_name) `
                -IpAddress $svr.Value.ipaddress `
                -DnsServer1 ('{0}11' -f $LabSubnetStub) `
                -OperatingSystem 'Windows Server 2022 Standard (Desktop Experience)' `
                -Gateway ('{0}1' -f $LabSubnetStub) 
        }
    }
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

# Install Everything
Install-Lab

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

# Write-ScreenInfo -Type Info -TaskStart -Message "Creating AD Service Accounts"
# Invoke-LabCommand `
#     -ActivityName "Creating AD Service Accounts" `
#     -ComputerName ((Get-LabMachines -role dc | Select-Object -First 1)) `
#     -ArgumentList @(
#         $config.activedirectory.users, 
#         $Domain_DN,  
#         ($config.domain_info.admin_password | ConvertTo-SecureString -AsPlainText -Force ) 
#     ) `
#     -ScriptBlock {
#         foreach ($user in $args[0].GetEnumerator()) {
#             $params = @{
#                 Name = $user.name
#                 Path = ("OU={0},{1}" -f $user.value.ou, $args[1])
#                 Description = ("`"{0}`"" -f $user.value.Description)
#                 DisplayName = ("`"{0}`"" -f $user.value.DisplayName)
#                 Enabled = ($user.value.Enabled -eq 1)
#                 PasswordNeverExpires = ($user.value.PasswordNeverExpires -eq 1)
#                 AccountPassword = $args[2]
#             }
#             New-ADUser @params
#         }
#     }
# Write-ScreenInfo -Type Info -TaskEnd -Message "AD Service Accounts Created"



# Install IIS and whatnot on Web servers
# if ( (Get-LabMachines -Role web).Count -gt 0 ) {
    # Install-LabWindowsFeature -ComputerName (Get-LabMachines web) -IncludeManagementTools -FeatureName $WF_Web 
    # Request-LabCertificate -Subject 'CN=vault' -SAN 'vault.ssop.local' -TemplateName WebServer -ComputerName (Get-LabMachines -Role web) -PassThru
    # Invoke-LabCommand `
        # -ActivityName "Configuring IIS for Vault" `
        # -ComputerName (Get-LabMachines -Role web) `
        # -ArgumentList @(($config.domain_info.domain_name).Split(".")[0],
            # "svc_vault_iis", 
            # $config.domain_info.admin_password
        # ),
        # -ScriptBlock {
            # Import-Module WebAdministration
            # $pool = New-WebAppPool -Name SecretServer
            # $pool.processModel.identityType = "SpecificUser"
            # $pool.processModel.userName = ($args[0]+"\"+$args[1])
            # $pool.processModel.password = $args[2]
            # $pool.processModel.loadUserProfile = $true
            # $pool.recycling.periodicRestart.time = "00:00:00"
            # $pool | Set-Item
            # New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port 443 -Protocol https
            # (Get-WebBinding -Name "Default Web Site" -Port 443 -Protocol https).AddSSLCertificate( `
                # (Get-ChildItem cert:\localmachine\my | Where-Object { $_.Subject -eq "CN=vault" }).Thumbprint, "my"
            # )
        # }
    # Copy-LabFileItem -Path $global:labSources\SoftwarePackages\Delinea\Version_11_7_000061.zip `
        # -ComputerName (Get-LabMachines -Role web) `
        # -DestinationFolderPath "C:\Temp\"
    # Invoke-LabCommand -ComputerName (Get-LabMachines -Role web) -ActivityName "Extract Secret Server files" -ScriptBlock {
            # Expand-Archive -Path C:\Temp\Version_11_7_000061.zip -DestinationPath C:\Temp
            # mkdir C:\inetpub\wwwroot\secretserver
            # Expand-Archive -Path c:\Temp\ss_update.zip -DestinationPath C:\inetpub\wwwroot\secretserver
        # }
    # Invoke-LabCommand `
        # -ComputerName (Get-LabMachines -Role web) `
        # -ActivityName "Setup Secret Server IIS Application" `
        # -ArgumentList @($config.activedirectory.domain+"\svc_vault_iis"),
        # -ScriptBlock {
            # ConvertTo-WebApplication `
                # -ApplicationPool SecretServer `
                # -PSPath "IIS:\Sites\Default Web Site\secretserver"
            # c:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis -ga $args[0]
        # }
# }

# # RabbitMQ Servers
# if ((Get-LabMachines -Role "rmq") -gt 0 ) {
#     $dl_path = "$global:labsources\SoftwarePackages\RMQ"

#     if ( -not (Test-Path $dl_path) ) {
#         mkdir $dl_path
#     }

#     $rmq_packages = @(
#         'https://download.visualstudio.microsoft.com/download/pr/27bcdd70-ce64-4049-ba24-2b14f9267729/d4a435e55182ce5424a7204c2cf2b3ea/windowsdesktop-runtime-8.0.11-win-x64.exe',
#         'https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.4/dotnet-hosting-9.0.4-win.exe',
#         'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi',
#         'https://downloads.marketplace.delinea.com/integrations/Downloads/RabbitMQ/latest/Delinea.RabbitMq.Helper.zip'
#     )

#     foreach ($pkg in $rmq_packages) {
#         Get-LabInternetFile -Path $global:labSources\SoftwarePackages\RMQ\ -Uri $pkg
#     }

#     $packs = @()
#     $packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\dotnet-hosting-9.0.4-win.exe -CommandLine "/install /quiet /norestart"
#     $packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\windowsdesktop-runtime-8.0.11-win-x64.exe -CommandLine "/install /quiet /norestart"
#     $packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\PowerShell-7.4.6-win-x64.msi -CommandLine "/quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1"

#     Install-LabSoftwarePackages -Machine (Get-LabMachines -Role rmq | Get-LabVM) -SoftwarePackage $packs

#     # Install Delinea RabbitMQ Helper
#     Copy-LabFileItem -Path $global:labSources\SoftwarePackages\RMQ\Delinea.RabbitMq.Helper.zip -ComputerName (Get-LabMachines -Role rmq) -DestinationFolderPath C:\Temp\RMQ\
#     Invoke-LabCommand -ActivityName "RMQ - Install Delinea RabbitMQ Helper" -ComputerName (Get-LabMachines -Role rmq) -ScriptBlock { 
#         Expand-Archive -Path c:\temp\rmq\Delinea.RabbitMq.Helper.zip -DestinationPath c:\Temp\rmq -Force
#         $file = Get-ChildItem C:\temp\rmq\delinea.rabbitmq.helper.*\Delinea.RabbitMQ.Helper.*.msi
#         Start-Process -Wait -FilePath "msiexec" -ArgumentList @("/i", $file.fullname, "/l*v", "C:\temp\rmq\rmq-helper-install.log", "/quiet")
#     }

#     Copy-LabFileItem -Path $global:labSources\SoftwarePackages\RMQ\Setup-Erlang-RMQ-Helper.ps1 -ComputerName (Get-LabMachines -Role rmq) -DestinationFolderPath C:\Temp\RMQ\
#     Invoke-LabCommand -ActivityName "RMQ - Install Erlang and RMQ" -ComputerName (Get-LabMachines -Role rmq)  -ScriptBlock {
#         & "C:\Program Files\PowerShell\7\pwsh.exe" -Command C:\Temp\RMQ\Setup-Erlang-RMQ-Helper.ps1
#     }
# }

Checkpoint-LabVM -SnapshotName "Fresh Build" -All

# . $global:labsources/dscconfigurations/ActiveDirectorySetup.ps1
# Invoke-LabDscConfiguration `
#     -ComputerName (Get-LabMachines -Role "DC" -First) `
#     -Configuration (Get-Command Active_Directory_Setup) `
#     -ConfigurationData $ConfigurationData `
#     -Parameter @{DefaultPassword=((Get-LabDomainDefinition).GetCredential())} 

Show-LabDeploymentSummary