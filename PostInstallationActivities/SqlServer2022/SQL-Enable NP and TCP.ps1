if ( $null -eq (Get-PackageProvider -Name NuGet) ) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
}
# Install-Module SQLServer -AllowClobber -Force
if ( $null -eq (get-module -ListAvailable | Where-Object {$_.Name -eq "dbatools"}) ) {
    Install-Module dbatools -Force
}

# Import-Module SQLServer
Import-Module dbatools

$svr_name = (hostname)

$changed = $false

Set-DbatoolsInsecureConnection | Out-Null

$db_network_config = Get-DbaNetworkConfiguration -SqlInstance $svr_name

if ( $false -eq $db_network_config.NamedPipesEnabled ) {
    $changed = $true
    Set-DbaNetworkConfiguration -SqlInstance $svr_name -EnableProtocol NamedPipes -Confirm:$false
}

if ( $false -eq $db_network_config.TcpIpEnabled ) {
    $changed = $true
    Set-DbaNetworkConfiguration -SqlInstance $svr_name -EnableProtocol Tcpip -Confirm:$false
}

if ( $null -eq (Get-DbaLogin -SqlInstance $svr_name -Login "ssop\svc_vault_iis") ) {
    $changed = $true
    New-DbaLogin -SqlInstance $svr_name -Login "ssop\svc_vault_iis"
}

if ( $null -eq (Get-DbaDatabase -SqlInstance $svr_name -Database "SecretServer") ) {
    $changed = $true
    New-DbaDatabase -SqlInstance $svr_name -Name "SecretServer"
}

$dbuser_params = @{}
$dbuser_params.SqlInstance = $svr_name
$dbuser_params.Database = "SecretServer"
$dbuser_params.User = "ssop\svc_vault_iis"
$dbuser_params.Login = "ssop\svc_vault_iis"

if ( $null -eq (Get-DbaDbUser @dbuser_params ) ) {
    $changed = $true
    New-DbaDbUser @dbuser_params
}

if (
    $null -eq 
        ( Get-DbaDbRoleMember `
            -SqlInstance ssop-sql01 `
            -Database secretserver `
            -Role "db_owner" `
            | Where-Object { 
                $_.Username -eq "ssop\svc_vault_iis" 
            }
        )
    ) { 
        $changed = $true
        Add-DbaDbRoleMember `
            -SqlInstance $svr_name `
            -Database "SecretServer" `
            -Role "db_owner" `
            -Member "ssop\svc_vault_iis" `
            -Confirm:$false
    }

if ( $changed ) {
    Write-Host "Detected changes, restarting SQL Server"
    Restart-DbaService -Type Engine -Force
}