#Set Windows Firewall to OFF
set-NetFirewallProfile -All -Enabled False

#Create User and Add to Local Administrator Group
$password = ConvertTo-SecureString 'Veeam1!' -AsPlainText -Force
new-localuser -Name autodeploy -Password $password
add-localgroupmember -Group administrators -Member autodeploy

Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
Get-Service sshd | Set-Service -StartupType Automatic
Start-Service sshd

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install cygwin cyg-get -y
cyg-get openssh python38 python38-pip python38-devel libssl-devel libffi-devel gcc-g++
choco install veeam-backup-and-replication-server -y
