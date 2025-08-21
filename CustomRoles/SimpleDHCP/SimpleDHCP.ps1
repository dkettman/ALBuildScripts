param(

)

# Some variables that are kind of ugly to get
$DNSName = (resolve-dnsname -name $env:computername).name[0]
$IPAddress = [System.Net.Dns]::GetHostAddresses($env:COMPUTERNAME) | Where-Object -Property AddressFamily -eq "InterNetwork"

Install-WindowsFeature -Name DHCP -IncludeManagementTools

# This is ugly, but it works ::shrug::
Add-DhcpServerInDC -DnsName $DNSName -IPAddress $IPAddress

# Build our DHCP Scope
$ScopeName = $env:USERDOMAIN
$ScopeStart = "192.168.12.100"
$ScopeEnd = "192.168.12.150"
$ScopeMask = "255.255.255.0"

$scope = Add-DhcpServerv4Scope -Name $ScopeName -StartRange $ScopeStart -EndRange $ScopeEnd -SubnetMask $ScopeMask -PassThru

# Set the DNS server Value
Set-DHCPServerv4OptionValue -ScopeId $scope.ScopeId -OptionId 6 -Value $IPAddress

