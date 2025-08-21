Describe "[$((Get-Lab).Name)] Delinea_SSOP_Web" -Tag Delinea_SSOP_Web {
    Context "Role deployment successful" {
        It "[Delinea_SSOP_Web] Should return the correct amount of machines" {
            (Get-LabVM).Where({$_.PreInstallationActivity.Where({$_.IsCustomRole}).RoleName -contains 'Delinea_SSOP_Web' -or $_.PostInstallationActivity.Where({$_.IsCustomRole}).RoleName -contains 'Delinea_SSOP_Web'})
        }
    }
}
