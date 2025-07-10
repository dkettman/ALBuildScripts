param(
    [Parameter(Mandatory)][string]$ComputerName #,
    #[Parameter(Mandatory)][string]$DomainName
)

$Features = @( 
    'Web-Server',
    'Web-WebServer',
    'Web-Common-Http',
    'Web-Default-Doc',
    'Web-Dir-Browsing',
    'Web-Http-Errors',
    'Web-Static-Content',
    'Web-Http-Redirect',
    'Web-Health',
    'Web-Http-Logging',
    'Web-Performance',
    'Web-Stat-Compression',
    'Web-Dyn-Compression',
    'Web-Security',
    'Web-Filtering',
    'Web-Windows-Auth',
    'Web-App-Dev',
    'Web-Net-Ext45',
    'Web-AppInit',
    'Web-Asp-Net45',
    'Web-ISAPI-Ext',
    'Web-ISAPI-Filter',
    'Web-Mgmt-Tools',
    'Web-Mgmt-Console',
    'Web-Scripting-Tools',
    'NET-Framework-45-Features',
    'NET-Framework-45-Core',
    'NET-Framework-45-ASPNET',
    'NET-WCF-Services45',
    'NET-WCF-HTTP-Activation45',
    'NET-WCF-TCP-Activation45',
    'NET-WCF-TCP-PortSharing45',
    'RSAT',
    'RSAT-Role-Tools',
    'RSAT-AD-Tools',
    'RSAT-AD-PowerShell',
    'RSAT-ADDS',
    'RSAT-AD-AdminCenter',
    'RSAT-ADDS-Tools',
    'RSAT-ADLDS',
    'RSAT-ADCS',
    'RSAT-ADCS-Mgmt',
    'RSAT-Online-Responder',
    'RSAT-DNS-Server',
    'WAS',
    'WAS-Process-Model',
    'WAS-Config-APIs'
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay -PassThru
$vm = Get-LabVM -ComputerName $ComputerName

# First, we will get a list of the missing Windows Features
$missing = Get-LabWindowsFeature `
                -NoDisplay `
                -ComputerName $ComputerName `
                -FeatureName $Features `
            | Where-Object { $_.Installed -eq $False } `
            | Select-Object Name

# Now, install anything that came back as "missing" so long as the list isn't empty
if ( ($null -ne $missing ) -or ($missing.Count -ne 0 )) { 
    Install-LabWindowsFeature `
        -ComputerName $ComputerName `
        -IncludeManagementTools `
        -FeatureName ($missing.Name)
}
$certs = Get-LabCertificate `
                -ComputerName $ComputerName `
                -FindType FindByTemplateName `
                -SearchString "WebServer" `
                -Location CERT_SYSTEM_STORE_LOCAL_MACHINE `
                -ErrorAction SilentlyContinue

if ( $certs.Certificate -notmatch "\sCN=vault\s" ) {
    Write-ScreenInfo "Did not find a matching Certificate"
    Request-LabCertificate `
        -ComputerName $vm `
        -Subject 'CN=vault' `
        -SAN ("vault.{0}" -f "ssop.local") `
        -TemplateName WebServer
}

Copy-LabFileItem -Path $global:labSources\SoftwarePackages\Delinea\ss_update.zip -DestinationFolderPath C:\Temp\ -ComputerName $vm
