#Set Windows Firewall to OFF
set-NetFirewallProfile -All -Enabled False

#Create User and Add to Local Administrator Group
$password = ConvertTo-SecureString 'Veeam1!' -AsPlainText -Force
new-localuser -Name autodeploy -Password $password
add-localgroupmember -Group administrators -Member autodeploy