Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module SQLServer -AllowClobber -Force

Import-Module SQLServer

$svr_name = (hostname)

$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $svr_name
# List the object properties, including the instance names.

# Enable the TCP protocol on the default instance.
$uri = "ManagedComputer[@Name='$svr_name']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']"
$Tcp = $wmi.GetSmoObject($uri)
$Tcp.IsEnabled = $true
$Tcp.Alter()
$Tcp

# Enable the named pipes protocol for the default instance.
$uri = "ManagedComputer[@Name='$svr_name']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']"
$Np = $wmi.GetSmoObject($uri)
$Np.IsEnabled = $true
$Np.Alter()
$Np