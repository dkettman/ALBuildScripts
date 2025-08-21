@{
    LabName                = 'SSOP'
    LabDomain              = 'ssop.local'
    
    Domain                 = @{
            Name          = 'ssop.local'
            AdminUser     = 'lab_admin'
            AdminPassword = 'New123Pass!!'
        }

    ISOs                   = @(
        @{
            Name = 'SQLServer2022'
            Path = 'F:\LabSources\ISOs\SQLServer2022-x64-ENU-Dev.iso'
        }
    )

    Networking             = @(
        @{
            Name             = 'ssop'
            AddressSpace     = '192.168.12.0/24'
            # HyperVProperties = @{
            #     SwitchType  = 'External'
            #     AdapterName = 'Ethernet'
            # }
        }
    )

    VMDefaults             = @{
        DnsServer1      = '192.168.12.3'
        Gateway         = '192.168.12.1'
        Memory          = 1GB
        OperatingSystem = 'Windows Server 2022 Standard (Desktop Experience)'
        Processors      = 2
        Domain          = 'ssop.local'
    }

    VMs                    = @(
        @{
            Name                     = 'ssop-dc01'
            IpAddress                = '192.168.12.3'
            Notes = @{ 
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
                        SiteSubnet = '192.168.12.0/24' 
                    } 
                },
                @{
                    Role       = 'CARoot'
                    Properties = @{}
                }
            )
        },
        @{
            Name                     = 'ssop-sql01'
            OperatingSystem          = 'Windows Server 2022 Standard'
            Memory = 8GB
            Processors = 4
            PostInstallationActivity = @(
                @{ 
                    CustomRole = 'SQLServer2022'
                    Variable   = @('ALConfig')
                }
            )
            Roles                    = @(
                @{
                    Role       = 'SQLServer2022'
                    Properties = @{
                        Features       = 'SQL,Tools'
                        SQLSvcAccount  = 'svc_sql'
                        SQLSvcPassword = 'New123Pass!!'
                    }
                }
            )
        },
        @{
            Name                     = 'ssop-rmq01'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @(
                @{ 
                    CustomRole = 'Delinea_SSOP_RMQ'
                    Properties = @{}
                    Variable   = @('ALConfig')
                }
            )
            Roles                    = @()
        },
        @{
            Name                     = 'ssop-rmq02'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @(
                @{ 
                    CustomRole = 'Delinea_SSOP_RMQ'
                    Properties = @{}
                    Variable   = @('ALConfig')
                }
            )
            Roles                    = @()
        },
        @{
            Name                     = 'ssop-rmq03'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @(
                @{ 
                    CustomRole = 'Delinea_SSOP_RMQ'
                    Properties = @{}
                    Variable   = @('ALConfig')
                }
            )
            Roles                    = @()
        },
        @{
            Name                     = 'ssop-web01'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @(
                @{ 
                    CustomRole = 'Delinea_SSOP_Web'
                    Properties = @{}
                    Variable   = @('ALConfig')
                }
            )
            Roles                    = @()
        },
        @{
            Name                     = 'ssop-web02'
            OperatingSystem          = 'Windows Server 2022 Standard (Desktop Experience)'
            PostInstallationActivity = @(
                @{ 
                    CustomRole = 'Delinea_SSOP_Web'
                    Properties = @{}
                    Variable   = @('ALConfig')
                }
            )
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
