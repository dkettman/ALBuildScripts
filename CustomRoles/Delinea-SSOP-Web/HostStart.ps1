param(
    [Parameter(Mandatory)]
    [string[]]$FeatureName,

    [Parameter(Mandatory)]
    [string]$DomainName
)

Install-LabWindowsFeature `
    -IncludeManagementTools `
    -FeatureName $FeatureName

Request-LabCertificate `
    -Subject 'CN=vault' `
    -SAN "vault."+$DomainName `
    -TemplateName WebServer

Copy-LabFileItem -Path $global:labSources\SoftwarePackages\Delinea\ss_update.zip -DestinationFolderPath C:\Temp\
