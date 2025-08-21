Describe "[$((Get-Lab).Name)] Delinea_SSOP_DC" -Tag Delinea_SSOP_DC {
    Context "Role deployment successful" {
        It "[Delinea_SSOP_DC] Should return the correct amount of machines" {
            (Get-LabVM).Where({$_.PreInstallationActivity.Where({$_.IsCustomRole}).RoleName -contains 'Delinea_SSOP_DC' -or $_.PostInstallationActivity.Where({$_.IsCustomRole}).RoleName -contains 'Delinea_SSOP_DC'})
        }
    }
}
