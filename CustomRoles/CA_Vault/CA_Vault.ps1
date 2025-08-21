param(

)

$tmp_path = 'C:\Temp\CA_Vault'

$zip_files = Get-ChildItem -Path $tmp_path\*zip 

$zip_files | ForEach-Object {
    Expand-Archive -Path $_.FullName -DestinationPath $tmp_path\
}

