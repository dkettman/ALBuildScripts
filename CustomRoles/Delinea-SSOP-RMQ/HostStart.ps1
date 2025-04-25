$dl_path = "$global:labsources\SoftwarePackages\RMQ"

if ( -not (Test-Path $dl_path) ) {
    mkdir $dl_path
}

$rmq_packages = @(
    'https://download.visualstudio.microsoft.com/download/pr/27bcdd70-ce64-4049-ba24-2b14f9267729/d4a435e55182ce5424a7204c2cf2b3ea/windowsdesktop-runtime-8.0.11-win-x64.exe',
    'https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.4/dotnet-hosting-9.0.4-win.exe',
    'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi',
    'https://downloads.marketplace.delinea.com/integrations/Downloads/RabbitMQ/latest/Delinea.RabbitMq.Helper.zip'
)

foreach ($pkg in $rmq_packages) {
    Get-LabInternetFile -Path $global:labSources\SoftwarePackages\RMQ\ -Uri $pkg
}

$packs = @()
$packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\dotnet-hosting-9.0.4-win.exe -CommandLine "/install /quiet /norestart"
$packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\windowsdesktop-runtime-8.0.11-win-x64.exe -CommandLine "/install /quiet /norestart"
$packs += Get-LabSoftwarePackage -Path $labsources\SoftwarePackages\RMQ\PowerShell-7.4.6-win-x64.msi -CommandLine "/quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1"

Install-LabSoftwarePackages -Machine (Get-LabMachineDefinition $ComputerName) -SoftwarePackage $packs

Copy-LabFileItem -Path $global:labSources\SoftwarePackages\RMQ\Delinea.RabbitMq.Helper.zip -ComputerName $ComputerName -DestinationFolderPath C:\Temp\RMQ\
Copy-LabFileItem -Path $global:labSources\SoftwarePackages\RMQ\Setup-Erlang-RMQ-Helper.ps1 -ComputerName $ComputerName -DestinationFolderPath C:\Temp\RMQ\