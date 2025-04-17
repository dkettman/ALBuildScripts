$u1 = "foo"; 
$p1 = 'bar' | ConvertTo-SecureString -AsPlainText -Force; 

$u2 = "admin"; 
$p2 = 'admin' | ConvertTo-SecureString -AsPlainText -Force; 

$cred = [PSCredential]::New($u1,$p1); 
$cred_admin = [PSCredential]::New($u2,$p2); 

Import-Module "C:\Program Files\Delinea Software Ltd\RabbitMq Helper\Delinea.RabbitMq.Helper.PSCommands.dll" -Force ; 
Install-Connector -AgreeRabbitMqLicense -AgreeErlangLicense -Credential $cred -AdminCredential $cred_admin 
Enable-RabbitMqManagement