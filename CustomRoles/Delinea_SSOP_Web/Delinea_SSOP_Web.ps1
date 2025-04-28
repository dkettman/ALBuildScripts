param (
    [Parameter(Mandatory)]
    [string]
    $DomainName,

    [Parameter(Mandatory)]
    [String]
    $AppPoolUsername,

    [Parameter(Mandatory)]
    [String]
    $AppPoolPassword

)

Import-Module WebAdministration
$pool = New-WebAppPool -Name SecretServer
$pool.processModel.identityType = "SpecifiedUser"
$pool.processModel.userName = (($DomainName).Split(".")[0]+"\"+$AppPoolUsername)
$pool.processModel.password = $AppPoolPassword
$pool.processModel.loadUserProfile = $true
$pool.recycling.perodicRestart.time = "00:00:00"
$pool | Set-Item

New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port 443 -Protocol https

mkdir C:\inetpub\wwwroot\SecretServer
Expand-Archive -Path C:\Temp\ss_update.zip -DestinationPath C:\inetpub\wwwroot\SecretServer

ConvertTo-WebApplication -ApplicationPool SecretServer `
    -PSPath "IIS:\Sites\Default Web Site\SecretServer"

C:\Windows\Microsoft.Net\Framework\v4.0.30319\aspnet_regiis -ga (($DomainName).Split(".")[0]+"\"+$AppPoolUsername)

