#Set Windows Firewall to OFF
set-NetFirewallProfile -All -Enabled False

#Create User and Add to Local Administrator Group
$password = ConvertTo-SecureString 'Veeam1!' -AsPlainText -Force
new-localuser -Name autodeploy -Password $password
add-localgroupmember -Group administrators -Member autodeploy

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install cygwin cyg-get -y
cyg-get openssh python38 python38-pip python38-devel libssl-devel libffi-devel gcc-g++
