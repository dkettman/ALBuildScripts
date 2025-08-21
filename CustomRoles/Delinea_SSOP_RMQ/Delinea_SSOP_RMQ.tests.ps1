Describe "[$((Get-Lab).Name)] Delinea_SSOP_RMQ" -Tag Delinea_SSOP_RMQ {
    Context "Role deployment successful" {
        It "[Delinea_SSOP_RMQ] Should return the correct amount of machines" {
            (Get-LabVM).Where({ $_.PreInstallationActivity.Where({ $_.IsCustomRole }).RoleName -contains 'Delinea_SSOP_RMQ' -or $_.PostInstallationActivity.Where({ $_.IsCustomRole }).RoleName -contains 'Delinea_SSOP_RMQ' })
        }
    }
    Context "Delinea RabbitMQ Helper Installed" {
        foreach ( $vm in (Get-LabVM).Where({ $_.PreInstallationActivity.Where({ $_.IsCustomRole }).RoleName -contains 'Delinea_SSOP_RMQ' -or $_.PostInstallationActivity.Where({ $_.IsCustomRole }).RoleName -contains 'Delinea_SSOP_RMQ' })) {
            It "[$vm] Should have Delinea RabbitMQ Helper installed" -TestCases @{
                vm = $vm
            } {
                $query = 'Select * from Win32_SoftwareElement where Name = "Delinea.RabbitMq.Helper.exe"'
                $session = New-LabCimSession -ComputerName $vm
                (Get-CimInstance -Query $query -CimSession $session).Count | Should -Be 1
            }

            It "[$vm] Should have RabbitMQ installed and running" -TestCases @{
                vm = $vm
            } {
                $query = 'Select State from Win32_Service where Name = "RabbitMQ"'
                $session = New-LabCimSession -ComputerName $vm
                (Get-CimInstance -Query $query -CimSession $session).Count | Should -Be 1
            }
        }
    }
}