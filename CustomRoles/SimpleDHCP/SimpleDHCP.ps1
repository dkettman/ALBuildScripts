[CmdletBinding()]
param(
    [Parameter]$ScopeSplat,
    [Parameter]$DHCPServerOptions
)

netsh dhcp add securitygroups
Restart-Service DHCPServer

Add-DhcpServerInDC `
    -DnsName ("{0}.{1}" -f $env:COMPUTERNAME,$ALConfig.Domain.Name) `
    -IPAddress 192.168.13.88

Set-ItemProperty `
    -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 `
    -Name ConfigurationState `
    -Value 2

Set-DhcpServerv4DnsSetting `
    -ComputerName ($env:COMPUTERNAME) `
    -DynamicUpdates "Always" `
    -DeleteDnsRRonLeaseExpiry $True

$DHCPDNSAcct = [PSCredential]::New($ALConfig.Domain.AdminUser, ($ALConfig.Domain.AdminPassword | ConvertTo-SecureString -AsPlainText -Force ))
Set-DHCPServerDnsCredential `
    -Credential  $DHCPDNSAcct `
    -ComputerName $env:COMPUTERNAME

if ( Get-DhcpServerv4Scope `
        -ScopeId ($scopesplat.startrange -replace "\d+$","0") `
        -ErrorAction SilentlyContinue ) {
    Write-Warning "Scope already exists, will not overwrite. Skipping."
} else {
    Add-DhcpServerv4Scope @ScopeSplat
}

foreach ( $DHCPServerOption in $DHCPServerOptions ) {
    Set-DhcpServerv4OptionValue @DHCPServerOption
}

