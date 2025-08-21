param(
    #[Parameter()][string]$ComputerName,
    #[Parameter()][hashtable]$Config
    [Parameter()]$Config = $ALConfig
)

# $config | Export-Clixml -Depth 10 -Path C:\config.xml

$Domain_DN = ("DC={0}" -f $Config.Domain.Name.Replace('.', ',DC='))

foreach ( $ou in $Config.ActiveDirectoryObjects.OUs.getEnumerator() ) {
    $params = @{}
    $params.Path = $Domain_DN
    if ( $null -eq (Get-ADOrganizationalUnit -Filter ("Name -eq '{0}'" -f $ou.Name))) {
        Write-Host ("Creating {0}" -f $ou.Name)
        $params.Name = $ou.Name
        $params.Description = $ou.Description
        $params.ProtectedFromAccidentalDeletion = $false
        if ( $ou.ContainsKey("Path") ) { $params.Path = ("{0},{1}" -f $ou.Path, $Domain_DN) }
        New-ADOrganizationalUnit @params
    }  
}

foreach ($user in $Config.ActiveDirectoryObjects.Users.GetEnumerator()) {
    if ( $null -eq ( Get-ADUser -Filter ("Name -eq '{0}'" -f $user.Name ) ) ) {
        $params = @{
            Name                 = $user.Name
            Path                 = ("{0},{1}" -f $user.Path, $Domain_DN)
            Description          = ("{0}" -f $user.Description)
            DisplayName          = ("{0}" -f $user.DisplayName)
            Enabled              = ($user.Enabled -eq 1)
            PasswordNeverExpires = ($user.PasswordNeverExpires -eq 1)
            AccountPassword      = ($config.Domain.AdminPassword | ConvertTo-SecureString -AsPlainText -Force ) 
        }
        New-ADUser @params
    }
}
