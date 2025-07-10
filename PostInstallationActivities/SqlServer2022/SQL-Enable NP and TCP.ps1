if ( $null -eq (Get-PackageProvider -Name NuGet) ) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$true
}
# Install-Module SQLServer -AllowClobber -Force
if ( $null -eq (get-module -ListAvailable | where {$_.Name -eq "dbatools"}) ) {
    Install-Module dbatools -Force
}

# Import-Module SQLServer
Import-Module dbatools

$svr_name = (hostname)

Set-DbatoolsInsecureConnection

Set-DbaNetworkConfiguration -SqlInstance $svr_name -EnableProtocol NamedPipes -Confirm:$false
Set-DbaNetworkConfiguration -SqlInstance $svr_name -EnableProtocol Tcpip -Confirm:$false

if ( $null -eq (Get-DbaLogin -SqlInstance $svr_name -Login "ssop\svc_vault_iis") ) {
    New-DbaLogin -SqlInstance $svr_name -Login "ssop\svc_vault_iis"
}

if ( $null -eq (Get-DbaDatabase -SqlInstance $svr_name -Database "SecretServer") ) {
    New-DbaDatabase -SqlInstance $svr_name -Name "SecretServer"
}

$dbuser_params = @{}
$dbuser_params.SqlInstance = $svr_name
$dbuser_params.Database = "SecretServer"
$dbuser_params.User = "ssop\svc_vault_iis"
$dbuser_params.Login = "ssop\svc_vault_iis"

if ( $null -eq (Get-DbaDbUser @dbuser_params ) ) {
    New-DbaDbUser @dbuser_params
}

if (
    $null -eq 
        ( Get-DbaDbRoleMember `
            -SqlInstance ssop-sql01 `
            -Database secretserver `
            -Role "db_owner" `
            | Where { 
                $_.Username -eq "ssop\svc_vault_iis" 
            }
        )
    ) { 
        Add-DbaDbRoleMember `
            -SqlInstance $svr_name `
            -Database "SecretServer" `
            -Role "db_owner" `
            -Member "ssop\svc_vault_iis" `
            -Confirm:$false
    }

Restart-DbaService -Type Engine -Force