param(
    [Parameter(Mandatory)][string]$ComputerName,
    [Parameter(Mandatory)][hashtable]$Config,
    [Parameter(Mandatory)][string]$Domain_DN
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay -PassThru
$vm = Get-LabVM -ComputerName $ComputerName


Write-ScreenInfo -Type Info -TaskStart -Message "Setting up AD Objects"
# Create AD Infrastructure and service accounts
# TODO: Create a function to deal with this instead to allow for recursion
## Lets start with OUs
Invoke-LabCommand `
    -ActivityName "Creating AD OUs" `
    -ComputerName $vm `
    -ArgumentList $config.activeDirectory.ous `
    -ScriptBlock {
        foreach ( $ou in $args[0].getEnumerator() ) {
            $parent = ""
            if ( $null -eq (Get-ADOrganizationalUnit -Filter ("Name -eq '{0}'" -f $ou.Name))) {
                $parent = New-ADOrganizationalUnit `
                                -Name $ou.Name `
                                -Description $ou.Description `
                                -ProtectedFromAccidentalDeletion:$false `
                                -PassThru
            } else {
                $parent = Get-ADOrganizationalUnit -Filter ("Name -eq '{0}'" -f $ou.Name)
            }
            if ( $ou.Value.ContainsKey("children") ) { 
                foreach ( $kids in $ou.Value.children.GetEnumerator() ) { 
                    foreach ( $kid in $kids ) { 
                        if ( (Get-ADOrganizationalUnit -Filter ("Name -eq '{0}'" -f $kid.Name) ) -eq $null ) {
                            $parent = New-ADOrganizationalUnit `
                                            -Name $kid.Name `
                                            -Description $kid.Value.Description `
                                            -Path $parent.DistinguishedName `
                                            -ProtectedFromAccidentalDeletion:$false `
                                            -Passthru
                        }
                    } 
                } 
            } 
        }
    }
Write-ScreenInfo -Type Info -TaskEnd -Message "AD OUs Created"

Write-ScreenInfo -Type Info -TaskStart -Message "Creating AD Service Accounts"
Invoke-LabCommand `
    -ActivityName "Creating AD Service Accounts" `
    -ComputerName $vm `
    -ArgumentList @(
        $config.activeDirectory.users, 
        $Domain_DN,  
        ($config.admin_password | ConvertTo-SecureString -AsPlainText -Force ) 
    ) `
    -ScriptBlock {
        foreach ($user in $args[0].GetEnumerator()) {
            if ( ( Get-ADUser -Filter ("Name -eq '{0}'" -f $user.Name ) ) -eq $null ) {
                $params = @{
                    Name = $user.name
                    Path = ("{0},{1}" -f $user.value.Path, $args[1])
                    Description = ("{0}" -f $user.value.Description)
                    DisplayName = ("{0}" -f $user.value.DisplayName)
                    Enabled = ($user.value.Enabled -eq 1)
                    PasswordNeverExpires = ($user.value.PasswordNeverExpires -eq 1)
                    AccountPassword = $args[2]
                }
                New-ADUser @params
            }
        }
    }
Write-ScreenInfo -Type Info -TaskEnd -Message "AD Service Accounts Created"
