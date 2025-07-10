Import-Module WebAdministration
$pool = New-WebAppPool -Name SecretServer
$pool.processModel.identityType = 3
$pool.processModel.idleTimeout = "00:00:00"
$pool.processModel.loadUserProfile = $true
$pool.processModel.userName = "ssop\svc_vault_iis"
$pool.processModel.password = "New123Pass!"
$pool.recycling.periodicRestart.time = "00:00:00"
$pool | Set-Item

mkdir C:\inetpub\wwwroot\SecretServer
Expand-Archive -Path C:\Temp\ss_update.zip -DestinationPath C:\inetpub\wwwroot\SecretServer

ConvertTo-WebApplication -ApplicationPool SecretServer `
    -PSPath "IIS:\Sites\Default Web Site\SecretServer"

C:\Windows\Microsoft.Net\Framework\v4.0.30319\aspnet_regiis -ga (($DomainName).Split(".")[0]+"\"+$AppPoolUsername)

$binding = Get-WebBinding -Name "Default Web Site" -Port 443 -Protocol https
if ($null -eq $binding) {
    New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port 443 -Protocol https
    (Get-WebBinding -Name "Default Web Site" -Port 443 -Protocol https).AddSSLCertificate( `
        (Get-ChildItem cert:\localmachine\my | Where-Object { $_.Subject -eq "CN=vault"})[0].Thumbprint, "my")
}

$dirs = @( "c:\inetpub\wwwroot\SecretServer", 
           "c:\Windows\Temp" 
        )

foreach ($dir in $dirs) {
    $acl = Get-Acl $dir
    $ar = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "ssop\svc_vault_iis", 
            "FullControl", 
            "ContainerInherit,ObjectInherit", 
            "None", 
            "Allow"
        )
    $acl.SetAccessRule($ar)
    set-acl $dir $acl
}



# Create Shortcut on global Desktop for Secret Server
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("C:\ProgramData\Desktop\Secret Server.lnk")
$shortcut.TargetPath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$shortcut.Arguments = "http://localhost/SecretServer"
$shortcut.IconLocation = "C:\inetpub\wwwroot\SecretServer\favicon.ico,0"
$shortcut.Description = "Link to Secret Server"
$shortcut.Save()
