# Import config.json

$config = Get-Content config.json | ConvertFrom-JSON -AsHashtable

$LabName = $config.lab_name
$LabSubnet = $config.network_info.lab_subnet
$LabSubnetStub = ($LabSubnet | Select-String -Pattern '(\d{1,3}\.\d{1,3}\.\d{1,3}\.)\d{1,3}\/\d{1,2}').Matches.Groups[1].Value

function Get-LabVMIP {
    param (
        $Role,
        $Hostname
    )
    $labsubnetstub + [string]( [int]($config.network_info.role_ips.$Role) + [int]($Hostname | Select-String -Pattern '.*(\d)').Matches.Groups[1].Value )
}

foreach ($s in $config.svrs.Keys) {
   $config.svrs.$s.ipaddress = Get-LabVMIP $config.svrs.$s.role $s
}

