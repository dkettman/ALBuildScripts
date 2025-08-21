param(
    [Parameter(Mandatory)]
    [string]$ComputerName
)

$packs = @()

Import-Lab -Name 'capam'

$vc_redist_pkgs = @(
    'https://aka.ms/vs/17/release/vc_redist.x86.exe',
    'https://aka.ms/vs/17/release/vc_redist.x64.exe'
)

$vc_redist_pkgs | ForEach-Object {
    $pkg = Get-LabInternetFile -Uri $_ -Path $global:LabSources\SoftwarePackages\CyberArk\CA_Vault -PassThru
    $packs += Get-LabSoftwarePackage -Path $pkg.FullName -CommandLine /S
}

Install-LabSoftwarePackages -Machine (Get-LabVM -ComputerName $ComputerName) -SoftwarePackage $packs

Copy-LabFileItem -Path $global:LabSources\SoftwarePackages\CyberArk\CA_Vault\*zip -ComputerName (Get-LabVM -ComputerName $ComputerName) -DestinationFolderPath C:\Temp\CA_Vault
