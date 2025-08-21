@{
    LabName                = 'CAOP'
    LabDomain              = 'caop.local'
    
    Domain                 = @{
        Name          = 'caop.local'
        AdminUser     = 'lab_admin'
        AdminPassword = 'New123Pass!!'
    }

    Networking             = @(
        @{
            Name         = 'caop'
            AddressSpace = '192.168.13.0/24'
        }
    )

    VMDefaults             = @{
        Memory          = 1.5GB
        OperatingSystem = 'Windows Server 2022 Standard (Desktop Experience)'
        Processors      = 2
    }

    VMs                    = @(
        @{
            Name                     = 'caop-dc01'
            IpAddress                = '192.168.13.3'
            DnsServer1               = '192.168.13.3'
            Gateway                  = '192.168.13.1'
            Network                  = 'caop'
            Domain                   = 'caop.local'
            Notes                    = @{ 
                Roles = "Domain Controller" 
            }
            OperatingSystem          = 'Windows Server 2022 Standard'
            PostInstallationActivity = @(
                @{ 
                    CustomRole = 'Delinea_SSOP_DC'
                    Properties = @{}
                    Variable   = @('ALConfig')
                    KeepFolder = $true
                }
            )
            Roles                    = @(
                @{ 
                    Role       = 'RootDC' 
                    Properties = @{ 
                        SiteName   = 'Kalamazoo'; 
                        SiteSubnet = '192.168.13.0/24' 
                    } 
                },
                @{
                    Role       = 'CARoot'
                    Properties = @{}
                }
            )
        },
        @{
            Name                     = 'caop-vlt01'
            Memory                   = 4GB
            Network                  = 'caop'
            DnsServer1               = '192.168.13.3'
            Gateway                  = '192.168.13.1'
            Domain                   = 'caop.local'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @()
            Roles                    = @()
        },
        @{
            Name                     = 'caop-app01'
            Memory                   = 4GB
            Network                  = 'caop'
            DnsServer1               = '192.168.13.3'
            Gateway                  = '192.168.13.1'
            Domain                   = 'caop.local'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @()
            Roles                    = @()
        },
        @{
            Name                     = 'caop-app02'
            Domain                   = 'caop.local'
            DnsServer1               = '192.168.13.3'
            Gateway                  = '192.168.13.1'
            Memory                   = 4GB
            Network                  = 'caop'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @()
            Roles                    = @()
        },
        @{
            Name                     = 'caop-web01'
            Memory                   = 4GB
            Network                  = 'caop'
            DnsServer1               = '192.168.13.3'
            Gateway                  = '192.168.13.1'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @()
            Roles                    = @()
        }
    )

    ## Post Installation Activity (Custom Role) Data
    ### (Delinea_SSOP_DC) Active Directory Objects
    #### The OUs and Users will be created in the order listed. 
    #### This will ensure that any parent OUs will be created first.
    ActiveDirectoryObjects = @{
        OUs   = @(
            @{ 
                Name        = 'Service Accounts'
                Description = 'Holds Application Service Accounts'
            },
            @{ 
                Name        = 'Domain Users'
                Description = 'Holds Domain User Accounts'
            },
            @{
                Name        = 'Admins'
                Description = 'Holds Elevated Administrative User Accounts'
                Path        = 'OU=Domain Users'
            }
            @{
                Name        = 'Domain Groups'
                Description = 'Holds Groups of Domain Users and Service Accounts'
            }
        )
        Users = @(
            @{
                Name                 = 'svc_vault_iis'
                Path                 = 'OU=Service Accounts'
                Description          = 'Used for Vault IIS Service'
                DisplayName          = 'Vault IIS Service'
                Enabled              = $true
                PasswordNeverExpires = $true
            }
            @{
                Name                 = 'svc_vault_sql'
                Path                 = 'OU=Service Accounts'
                Description          = 'Used for Vault SQL Service'
                DisplayName          = 'Vault SQL Service'
                Enabled              = $true
                PasswordNeverExpires = $true
            }
            @{
                Name                 = 'svc_vault_rpc'
                Path                 = 'OU=Service Accounts'
                Description          = 'Used for Vault Password Changers'
                DisplayName          = 'Vault Password Changer'
                Enabled              = $true
                PasswordNeverExpires = $true
            }
        )
    }
}
