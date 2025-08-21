param(
    [Parameter(Mandatory)]
    [string]$ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay -PassThru
$vm = Get-LabVM -ComputerName $ComputerName

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
        -SAN ("vault.{0}" -f (Get-LabDomainDefinition).Name )`
        -TemplateName WebServer
}

Copy-LabFileItem -Path $global:labSources\SoftwarePackages\Delinea\ss_update.zip -DestinationFolderPath C:\Temp\ -ComputerName $vm

$iis_win_features = @(
    "Web-Server",
    "Web-WebServer",
    "Web-Common-Http",
    "Web-Default-Doc",
    "Web-Dir-Browsing",
    "Web-Http-Errors",
    "Web-Static-Content",
    "Web-Http-Redirect",
    "Web-Health",
    "Web-Http-Logging",
    "Web-Performance",
    "Web-Stat-Compression", 
    "Web-Dyn-Compression",
    "Web-Security",
    "Web-Filtering",
    "Web-Windows-Auth",
    "Web-AppInit",
    "Web-Net-Ext45",
    "Web-Asp-Net45",
    "Web-ISAPI-Ext",
    "Web-ISAPI-Filter",
    "Web-Scripting-Tools",
    "Web-Mgmt-Console",
    "Web-Mgmt-Tools"
    "RSAT-AD-Tools",
    "RSAT-AD-PowerShell",
    "RSAT-ADDS",
    "RSAT-AD-AdminCenter",
    "RSAT-ADDS-Tools",
    "RSAT-ADLDS",
    "RSAT-ADCS",
    "RSAT-DNS-Server",
    "GPMC"
)

Install-LabWindowsFeature -ComputerName $ComputerName -FeatureName $iis_win_features -IncludeManagementTools