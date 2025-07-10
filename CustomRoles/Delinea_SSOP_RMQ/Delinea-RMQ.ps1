# Install Delinea RabbitMQ Helper
Expand-Archive -Path c:\temp\rmq\Delinea.RabbitMq.Helper.zip -DestinationPath c:\Temp\rmq -Force
$file = Get-ChildItem C:\temp\rmq\delinea.rabbitmq.helper.*\Delinea.RabbitMQ.Helper.*.msi
Start-Process -Wait -FilePath "msiexec" -ArgumentList @("/i", $file.fullname, "/l*v", "C:\temp\rmq\rmq-helper-install.log", "/quiet")

& "C:\Program Files\PowerShell\7\pwsh.exe" -Command C:\Temp\RMQ\Setup-Erlang-RMQ-Helper.ps1
