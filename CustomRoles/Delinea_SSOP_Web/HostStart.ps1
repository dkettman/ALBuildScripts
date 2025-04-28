param(
    [Parameter(Mandatory)]
    [string]$ComputerName,
    
    [Parameter(Mandatory)]
    [string]$DomainName,

    [Parameter(Mandatory)]
    [String]
    $AppPoolUsername,

    [Parameter(Mandatory)]
    [String]
    $AppPoolPassword
)

$Features = @( 
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

Write-Host ("Computer: {0}`nUsername: {1}`nPassword: {2}" -f $ComputerName, $AppPoolUsername, $AppPoolPassword)
Write-Host $Features

Install-LabWindowsFeature `
    -ComputerName (Get-LabMachineDefinition -ComputerName $ComputerName) `
    -IncludeManagementTools `
    -FeatureName $Features
    

# Request-LabCertificate `
#     -ComputerName $ComputerName `
#     -Subject 'CN=vault' `
#     -SAN ("vault.{0}" -f "dkettman.local") `
#     -TemplateName WebServer
    

# Copy-LabFileItem -Path $global:labSources\SoftwarePackages\Delinea\ss_update.zip -DestinationFolderPath C:\Temp\ -ComputerName $ComputerName
