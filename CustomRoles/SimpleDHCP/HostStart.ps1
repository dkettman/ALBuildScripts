param(
    [Parameter(Mandatory)]
    [string]$ComputerName
)


Import-Lab -Name $data.Name -NoValidation -NoDisplay -PassThru

$vm = Get-LabVM -ComputerName $ComputerName

$install_wf_DHCP = Install-LabWindowsFeature -ComputerName $vm -FeatureName DHCP -IncludeAllSubFeature -IncludeManagementTools -PassThru

if (!$install_wf_DHCP.Success) {
    Write-Error "Unable to install the DHCP server feature"
}

