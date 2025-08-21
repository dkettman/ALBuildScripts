#$data | ConvertTo-JSON -Depth 20 | Out-File -FilePath c:\jsondata.json

# if ( $data.Machines.Roles -notcontains "RootCA" ) {
#     Write-ScreenInfo -Message "This role can only be used if a Domain is installed!" -Type Error
#     break
# }