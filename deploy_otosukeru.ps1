<#
.SYNOPSIS
----------------------------------------------------------------------
Project Otosukeru - Dynamic Proxy Deployment with Terraform
----------------------------------------------------------------------
Version     : 1.2
Requires    : Veeam Backup & Replication v9.5 Update 4 or later
Supported   : Veeam Backup & Replication v10 BETA 2
Author      : Anthony Spiteri
Blog        : https://anthonyspiteri.net
GitHub      : https://www.github.com/anthonyspiteri

.DESCRIPTION
Known Issues and Limitations:
- vSphere API timeouts can happen during apply/destroy phase of Terraform. See Log file to troubleshoot.
- Speed of Proxy deployment depends on underlying infrastructure as well as VM Template. (Testing has shown 5 Windows Proxies can be deployed in 5 minutes)
- Bug on first run where Scale Down might take affect. Rerun with same commands to workaround.
#>

[CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$Windows,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$Ubuntu,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$CentOS,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$Destroy,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$DHCP,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [int]$SetProxies,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$ProxyPerHost,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$NASProxy,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$Workgroup
    )

if (!$Windows -and !$Ubuntu -and !$CentOS -and !$Destroy)
    {
        Write-Host ""
        Write-Host ":: - ERROR! Script was run without using a parameter..." -ForegroundColor Red -BackgroundColor Black
        Write-Host ":: - Please use: -Windows, -Ubuntu, -Centos or -Destroy" -ForegroundColor Yellow -BackgroundColor Black 
        Write-Host ""
        break
    }

$StartTime = Get-Date

#To be run on Server Isntalled with Veeam Backup & Replicaton
if (!(get-pssnapin -name VeeamPSSnapIn -erroraction silentlycontinue)) 
        {
         add-pssnapin VeeamPSSnapIn
        }

#Get Variables from Master Config
$config = Get-Content config.json | ConvertFrom-Json

function Pause
    {
        write-Host ""
        write-Host ":: Press Enter to continue..." -ForegroundColor Yellow -BackgroundColor Black
        Read-Host | Out-Null 
    }

function ConnectVBRServer
    {
        #Connect to the Backup & Replication Server and exit on fail
        Disconnect-VBRServer

        Try 
            {
                Connect-VBRServer -user $config.VBRDetails.Username -password $config.VBRDetails.Password
            }
        Catch 
            {
                Write-Host -ForegroundColor Red "ERROR: $_" -ErrorAction Stop
                Disconnect-VBRServer
                Stop-Transcript
                Write-Error -Exception  "Exiting as we couldn't connect to Veeam Server" -ErrorAction Stop
            }
    }

function WorkOutProxyCount
    {
        try
            {
                $JobObject = Get-VBRJob
                $Objects = $JobObject.GetObjectsInJob()
            }
        catch 
            {
                Write-Host -ForegroundColor Red "ERROR: $_" -ErrorAction Stop
                Stop-Transcript
                Write-Error -Exception "Exiting as you don't have any Jobs on the Veeam Server" -ErrorAction Stop
            }

        $JobObject = Get-VBRJob
        $VMcount = $Objects.count

        #Get ESXi Host Count
        $Hosts = Get-VBRServer -Type ESXi
        $HostCount = $Hosts.count

        if($VMcount -lt 10)
            {
                $VBRProxyCount = 2  
            }
        elseif ($VMcount -le 20)
            {
                $VBRProxyCount = 4
            }
        else 
            {
                $VBRProxyCount = 6
            }
        if($ProxyPerHost)
            {
                $VBRProxyCount = $HostCount
            }
        if($SetProxies)
            {
                $VBRProxyCount = $SetProxies
            }
 
        $global:ProxyCount = $VBRProxyCount
    }

function WorkOutIfScaleDown
    {
        $ProxyList = Get-Content proxy_ips.json | ConvertFrom-Json
        $ProxyArray =@($ProxyList)

        if($ProxyCount -lt $ProxyList.Value.Count) 
            {
                $ScaleDownValue = $True 
            } 
        else 
            { 
                $ScaleDownValue = $False 
            }
        $global:ScaleDown = $ScaleDownValue
    }

function RenameFileForAntiAffinity
    {
        $wkdir = Get-Location

        if($Windows)
            {
                Set-Location -Path .\proxy_windows
            }

        if($Ubuntu -or $CentOS)
            {
                Set-Location -Path .\proxy_linux
            }

        Rename-Item .\anti-affinity_tf -NewName .\anti-affinity.tf
        Set-Location $wkdir
    }

function RenameFileBackForAntiAffinity
    {
        $wkdir = Get-Location

        if($Windows)
            {
                Set-Location -Path .\proxy_windows
            }

        if($Ubuntu -or $CentOS)
            {
                Set-Location -Path .\proxy_linux
            }

        Rename-Item .\anti-affinity.tf -NewName .\anti-affinity_tf
        Set-Location $wkdir
    }

function RenameFileForDHCP
    {
        $wkdir = Get-Location

        if($Windows)
            {
                Set-Location -Path .\proxy_windows
            }

        if($Ubuntu -or $CentOS)
            {
                Set-Location -Path .\proxy_linux
            }

        Rename-Item .\otosukeru-1.tf -NewName .\otosukeru-1_tf
        Rename-Item .\otosukeru-1-DHCP_tf -NewName .\otosukeru-1-DHCP.tf
        Set-Location $wkdir
    }

function RenameFileBackForDHCP
    {
        $wkdir = Get-Location

        if($Windows)
            {
                Set-Location -Path .\proxy_windows
            }

        if($Ubuntu -or $CentOS)
            {
                Set-Location -Path .\proxy_linux
            }

        Rename-Item .\otosukeru-1_tf -NewName .\otosukeru-1.tf
        Rename-Item .\otosukeru-1-DHCP.tf -NewName .\otosukeru-1-DHCP_tf
        Set-Location $wkdir
    }

    function RenameFileForWorkGroup
    {
        $wkdir = Get-Location

        if($Windows)
            {
                Set-Location -Path .\proxy_windows
            }

        Rename-Item .\otosukeru-1.tf -NewName .\otosukeru-1_tf
        Rename-Item .\otosukeru-1-NoAD_tf -NewName .\otosukeru-1-NoAD.tf
        Set-Location $wkdir
    }

function RenameFileBackForWorkGroup
    {
        $wkdir = Get-Location

        if($Windows)
            {
                Set-Location -Path .\proxy_windows
            }

        Rename-Item .\otosukeru-1_tf -NewName .\otosukeru-1.tf
        Rename-Item .\otosukeru-1-NoAD.tf -NewName .\otosukeru-1-NoAD_tf
        Set-Location $wkdir
    }

function WindowsProxyBuild 
    {
        $host.ui.RawUI.WindowTitle = "Deploying Windows Proxies with Terraform"
        
        $wkdir = Get-Location
        Set-Location -Path .\proxy_windows
        & .\terraform.exe init
        & .\terraform.exe apply --var "vsphere_proxy_number=$ProxyCount" -auto-approve
        & .\terraform.exe output -json proxy_ip_addresses > ..\proxy_ips.json
        & .\terraform.exe output -json proxy_vm_names > ..\proxy_vms.json
        Set-Location $wkdir
    }

function LinuxProxyBuild
    {
        $host.ui.RawUI.WindowTitle = "Deploying Linux Proxies with Terraform"

        if($Ubuntu)
            {
                $distro = "ubuntu"
            }

        if($CentOS)
            {
                $distro = "centos"
            }

        $wkdir = Get-Location
        Set-Location -Path .\proxy_linux
        & .\terraform.exe init
        & .\terraform.exe apply --var "vpshere_linux_distro=$distro" --var "vsphere_proxy_number=$ProxyCount" -auto-approve
        & .\terraform.exe output -json proxy_ip_addresses > ..\proxy_ips.json
        & .\terraform.exe output -json proxy_vm_names > ..\proxy_vms.json
        Set-Location $wkdir
    }

function ProxyDestroy 
    {
        if($Destroy -and $Windows)
            {
                $host.ui.RawUI.WindowTitle = "Destroying Windows Proxies with Terraform"
            
                $wkdir = Get-Location
                Set-Location -Path .\proxy_windows
                & .\terraform.exe destroy --force
                Set-Location $wkdir
            }

        if($Destroy -and ($Ubuntu -or $CentOS))
            {
                $host.ui.RawUI.WindowTitle = "Destroying Linux Proxies with Terraform"

                $wkdir = Get-Location
                Set-Location -Path .\proxy_linux
                & .\terraform.exe destroy --force
                Set-Location $wkdir
            }
    }

function AddVeeamProxy
    {
        $host.ui.RawUI.WindowTitle = "Adding Veeam Proxies"
        
        $ProxyList = Get-Content proxy_ips.json | ConvertFrom-Json
        $ProxyArray =@($ProxyList)

        $ProxyVMNames = Get-Content proxy_vms.json | ConvertFrom-Json
        $ProxyVMArray =@($ProxyVMNames)
    
        if(!$ProxyArray)
            {
                Write-Error -Exception "Exiting due to Terraform Proxy Deployment Issue" -ErrorAction Stop
            }

        if(!$Workgroup)
            {
                $WindowsUsername = $config.VBRDetails.Username
                $WindowsPassword = $config.VBRDetails.Password
                $WindowsDescription = "Windows Domain Account"
            }
        
        if($Workgroup)
            {
                $WindowsUsername = $config.VBRDetails.Username2
                $WindowsPassword = $config.VBRDetails.Password2
                $WindowsDescription = "Windows Server Account"
            }

        $ExistingWinCredential = Get-VBRCredentials -Name $WindowsUsername
        $ExistingLinuxCredential = Get-VBRCredentials | Where-Object {$_.Description -eq "Proxy Linux Admin"}

        if($Windows -and !$ExistingWinCredential) 
            {
                Add-VBRCredentials -Type Windows -User $WindowsUsername -Password $WindowsPassword -Description $WindowsDescription | Out-Null
            }

        if($Ubuntu -and !$ExistingLinuxCredential)
            {
                Add-VBRCredentials -Type Linux -User $config.LinuxProxy.LocalUsername -Password $config.LinuxProxy.LocalPasswordUbuntu -ElevateToRoot -Description "Proxy Linux Admin"  | Out-Null
            }

        if($CentOS -and !$ExistingLinuxCredential)
            {
                Add-VBRCredentials -Type Linux -User $config.LinuxProxy.LocalUsername -Password $config.LinuxProxy.LocalPasswordCentOS -ElevateToRoot -Description "Proxy Linux Admin"  | Out-Null
            }

        for ($i=0; $i -lt $ProxyCount; $i++)
            {
                $ProxyEntity = $ProxyArray.value[$i]
                $ProxyVMEntity = $ProxyVMArray.value[$i]
                $ProxyName = $ProxyArray.value[$i]

                #Return True or False if Proxy Exists in VBR
                $ProxyExists = Get-VBRViProxy | Where-Object {$_.Name -eq $ProxyName}

                #Add Proxy to Backup & Replication
                Write-Host ":: Adding Proxy Server to Backup & Replication" -ForegroundColor Yellow 

                if($Windows)
                    {
                        #Get and Set Windows Credential
                        if(!$ProxyExists)
                            {
                                $WindowsCredential = Get-VBRCredentials | where-object {$_.Description -eq $WindowsDescription}
                            } 

                        #Add Windows Server to VBR and Configure Proxy
                        if(!$ProxyExists)
                        {
                        try 
                            {
                                Add-VBRWinServer -Name $ProxyEntity -Description "Dynamic Veeam Proxy" -Credentials $WindowsCredential -ErrorAction Stop | Out-Null
                            }
                        Catch 
                            {
                                Write-Host -ForegroundColor Red "ERROR: $_" -ErrorAction Stop
		                        Get-VBRCredentials | where-object {$_.Description -eq $WindowsDescription} | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                                Stop-Transcript
                                Write-Error -Exception "Exiting due to issues adding Windows Proxy to Veeam Server" -ErrorAction Stop
                            }

                        Write-Host ":: Creating New Veeam Windows Proxy" -ForegroundColor Yellow
                        Add-VBRViProxy -Server $ProxyEntity -MaxTasks 4 -TransportMode HotAdd -ConnectedDatastoreMode Auto -EnableFailoverToNBD | Out-Null
                        }
                    }

                if ($Ubuntu -or $CentOS)
                    {
                        #Get and Set Linux Credentials and Set ProxyVM from VM Entity List
                        if(!$ProxyExists)
                            {
                                $LinuxCredential = Get-VBRCredentials | where-object {$_.Description -eq "Proxy Linux Admin"}
                            }

                        $ProxyVM = Find-VBRViEntity -Name $ProxyVMEntity
                        
                        if(!$ProxyExists)
                        {
                        try 
                            {
                                Add-VBRLinux -Name $ProxyEntity -Description "Dynamic Veeam Proxy" -Credentials $LinuxCredential -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
                            }
                        catch 
                            {
                                Write-Host -ForegroundColor Red "ERROR: $_" -ErrorAction Stop
		                        Get-VBRCredentials | where-object {$_.Description -eq "Proxy Linux Admin"} | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                                Stop-Transcript
                                Write-Error -Exception "Exiting due to issues adding Linux Proxy to Veeam Server" -ErrorAction Stop
                            }

                        Write-Host ":: Creating New Veeam Linux Proxy" -ForegroundColor Yellow
                        }

                        if(!$ProxyExists)
                        {
                        try 
                            {
                                Add-VBRViLinuxProxy -Server $ProxyEntity -Description "Dynamic Veeam Proxy" -MaxTasks 4 -ProxyVM $ProxyVM -Force -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
                            }
                        catch 
                            {
                                Write-Host -ForegroundColor Red "ERROR: $_" -ErrorAction Stop
		                        Get-VBRCredentials | where-object {$_.Description -eq "Proxy Linux Admin"} | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                                Stop-Transcript
                                Write-Error -Exception "Exiting due to issues Configuring Linux Proxy" -ErrorAction Stop 
                            }
                        }
                    }

                if ($ProxyExists) {Write-Host "--" $ProxyEntity "Exists in Configurtion" -ForegroundColor Green} else {Write-Host "--" $ProxyEntity "Configured" -ForegroundColor Green}
                Write-Host
            }
    }

    function AddVeeamNASProxy
    {
        $host.ui.RawUI.WindowTitle = "Adding Veeam NAS File Proxies"
        
        $ProxyList = Get-Content proxy_ips.json | ConvertFrom-Json
        $ProxyArray =@($ProxyList)
 
        if(!$ProxyArray)
            {
                Write-Error -Exception "Exiting due to Terraform Proxy Deployment Issue" -ErrorAction Stop
            }

        if(!$Workgroup)
            {
                $WindowsUsername = $config.VBRDetails.Username
                $WindowsPassword = $config.VBRDetails.Password
                $WindowsDescription = "Windows Domain Account"
            }
        
        if($Workgroup)
            {
                $WindowsUsername = $config.VBRDetails.Username2
                $WindowsPassword = $config.VBRDetails.Password2
                $WindowsDescription = "Windows Server Account"
            }
        
            $ExistingWinCredential = Get-VBRCredentials -Name $WindowsUsername

        if($Windows -and !$ExistingWinCredential) 
            {
                Add-VBRCredentials -Type Windows -User $WindowsUsername -Password $WindowsPassword -Description $WindowsDescription | Out-Null
            }

        for ($i=0; $i -lt $ProxyCount; $i++)
            {
                $ProxyEntity = $ProxyArray.value[$i]
                $ProxyName = $ProxyArray.value[$i]

                #Return True or False if Proxy Exists in VBR
                $NASProxyExists = Get-VBRNASProxyServer -Name $ProxyName

                #Add Proxy to Backup & Replication
                Write-Host ":: Adding NAS File Proxy Server to Backup & Replication" -ForegroundColor Yellow 

                if($Windows)
                    {
                        #Get and Set Windows Credential
                        if(!$NASProxyExists)
                            {
                                $WindowsCredential = Get-VBRCredentials | where-object {$_.Description -eq $WindowsDescription}
                            } 

                        #Add Windows Server to VBR and Configure Proxy
                        if(!$NASProxyExists)
                        {
                        try 
                            {
                                Add-VBRWinServer -Name $ProxyEntity -Description "Dynamic Veeam NAS File Proxy" -Credentials $WindowsCredential -ErrorAction Stop | Out-Null
                            }
                        Catch 
                            {
                                Write-Host -ForegroundColor Red "ERROR: $_" -ErrorAction Stop
		                        Get-VBRCredentials | where-object {$_.Description -eq $WindowsDescription} | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                                Stop-Transcript
                                Write-Error -Exception "Exiting due to issues adding NAS File Proxy to Veeam Server" -ErrorAction Stop
                            }

                        Write-Host ":: Creating New Veeam NAS File Proxy" -ForegroundColor Yellow
                        Add-VBRNASProxyServer -Server $ProxyEntity -ConcurrentTaskNumber 2 | Out-Null
                        }
                    }

                if ($NASProxyExists) {Write-Host "--" $ProxyEntity "Exists in Configurtion" -ForegroundColor Green} else {Write-Host "--" $ProxyEntity "Configured" -ForegroundColor Green}
                Write-Host
            }
    }

    function RemoveVeeamProxy
    {
        $host.ui.RawUI.WindowTitle = "Removing Veeam Proxies"

        $ProxyList = Get-Content proxy_ips.json | ConvertFrom-Json
        $ProxyArray =@($ProxyList)
        
        for ($i=0; $i -lt $ProxyCount; $i++)
            {
                $ProxyEntity = $ProxyArray.value[$i]
                $ProxyName = $ProxyArray.value[$i]

                #Return True or False if Proxy Exists in VBR
                $ProxyExists = Get-VBRViProxy | Where-object {$_.Name -eq $ProxyName}
                $NASProxyExists = Get-VBRNASProxyServer -Name $ProxyName

                if(!$Workgroup)
                {
                    $WindowsUsername = $config.VBRDetails.Username
                    $WindowsDescription = "Windows Domain Account"
                }
            
                if($Workgroup)
                {
                    $WindowsUsername = $config.VBRDetails.Username2
                    $WindowsDescription = "Windows Server Account"
                }

                #Remove Proxy From Backup & Replication
                if (!$NASProxy -and $ProxyExists)
                    {
                        Write-Host ":: Removing Proxy Server from Backup & Replication" -ForegroundColor Yellow
                        Get-VBRViProxy -Name $ProxyEntity | Remove-VBRViProxy -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                    }

                if ($NASProxy -and $NASProxyExists)
                    {
                        Write-Host ":: Removing NAS File Proxy from Backup & Replication" -ForegroundColor Yellow
                        Get-VBRNASProxyServer -Name $ProxyEntity | Remove-VBRNASProxyServer -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                    }

                Get-VBRServer -Type Windows -Name $ProxyEntity | Remove-VBRServer -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                Get-VBRServer -Type Linux -Name $ProxyEntity | Remove-VBRServer -Confirm:$false -WarningAction SilentlyContinue | Out-Null

                Write-Host "--" $ProxyEntity "Removed" -ForegroundColor Red -BackgroundColor Black
                Write-Host
            }

            if($Windows) { Get-VBRCredentials | where-object {$_.Description -eq $WindowsDescription} | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null }
            if($Ubuntu -or $CentOS) { Get-VBRCredentials | where-object {$_.Description -eq "Proxy Linux Admin"} | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null }
    }

function ScaleDownVeeamProxy
    {
        $host.ui.RawUI.WindowTitle = "Scaling Down Veeam Proxies"

        $ProxyList = Get-Content proxy_ips.json | ConvertFrom-Json
        $ProxyArray =@($ProxyList)

        #Reverse Proxy Array to make sure we are removing oldest Proxy to match Terraform
        [array]::Reverse($ProxyList.Value)

        #Set Iterations of For Loop
        $ProxyArrayFinish = ($ProxyArray.Value.Count - $ProxyCount)
        
        for ($i=0; $i -lt $ProxyArrayFinish; $i++)
            {
                $ProxyEntity = $ProxyList.value[$i]
                $ProxyName = $ProxyList.value[$i]

                #Return True or False if Proxy Exists in VBR
                $ProxyExists = Get-VBRViProxy | Where-Object {$_.Name -eq $ProxyName}
                $NASProxyExists = Get-VBRNASProxyServer -Name $ProxyName

                #Remove Proxy From Backup & Replication
                if (!$NASProxy -and $ProxyExists)
                    {
                        Write-Host ":: Removing Proxy Server from Backup & Replication" -ForegroundColor Yellow
                        Get-VBRViProxy -Name $ProxyEntity | Remove-VBRViProxy -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                    }

                if ($NASProxy -and $NASProxyExists)
                    {
                        Write-Host ":: Removing NAS File Proxy from Backup & Replication" -ForegroundColor Yellow
                        Get-VBRNASProxyServer -Name $ProxyEntity | Remove-VBRNASProxyServer -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                    }
                Get-VBRServer -Type Windows -Name $ProxyEntity | Remove-VBRServer -Confirm:$false -WarningAction SilentlyContinue | Out-Null
                Get-VBRServer -Type Linux -Name $ProxyEntity | Remove-VBRServer -Confirm:$false -WarningAction SilentlyContinue | Out-Null

                Write-Host "--" $ProxyEntity "Removed" -ForegroundColor Red -BackgroundColor Black
                Write-Host
            }
    }

#Execute Functions
Start-Transcript logs\ProjectOtosukeru-Log.txt -Force

$StartTimeVB = Get-Date
ConnectVBRServer
Write-Host ""
Write-Host ":: - Connected to Backup & Replication Server - ::" -ForegroundColor Green -BackgroundColor Black
$EndTimeVB = Get-Date
$durationVB = [math]::Round((New-TimeSpan -Start $StartTimeVB -End $EndTimeVB).TotalMinutes,2)
Write-Host "Execution Time" $durationVB -ForegroundColor Green -BackgroundColor Black
Write-Host ""

$StartTimeLR = Get-Date
Write-Host ""
Write-Host ":: - Getting Job Details and Working out Dynamix Proxy Count - ::" -ForegroundColor Green -BackgroundColor Black
WorkOutProxyCount
WorkOutIfScaleDown
$EndTimeLR = Get-Date
$durationLR = [math]::Round((New-TimeSpan -Start $StartTimeLR -End $EndTimeLR).TotalMinutes,2)
Write-Host "Execution Time" $durationLR -ForegroundColor Green -BackgroundColor Black
Write-Host ""

if ($Windows -and !$Destroy -and !$ScaleDown){
    #Run the code for Windows Proxies
    
    if ($ProxyPerHost)
        {
            RenameFileForAntiAffinity 
        }

    if ($DHCP)
        {
            RenameFileForDHCP
        }

    if ($Workgroup)
        {
            RenameFileForWorkGroup
        }  

    $StartTimeTF = Get-Date
    WindowsProxyBuild
    Write-Host ""
    Write-Host ":: - Windows Proxy VMs Deployed via Terraform - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeTF = Get-Date
    $durationTF = [math]::Round((New-TimeSpan -Start $StartTimeTF -End $EndTimeTF).TotalMinutes,2)
    Write-Host "Execution Time" $durationTF -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    if (!$NASProxy)
        {
            $StartTimeTF = Get-Date
            AddVeeamProxy
            Write-Host ""
            Write-Host ":: - Windows Proxies Configured - ::" -ForegroundColor Green -BackgroundColor Black
            $EndTimeTF = Get-Date
            $durationTF = [math]::Round((New-TimeSpan -Start $StartTimeTF -End $EndTimeTF).TotalMinutes,2)
            Write-Host "Execution Time" $durationTF -ForegroundColor Green -BackgroundColor Black
            Write-Host ""
        }

    if ($NASProxy)
        {
            $StartTimeTF = Get-Date
            AddVeeamNASProxy
            Write-Host ""
            Write-Host ":: - NAS File Proxies Configured - ::" -ForegroundColor Green -BackgroundColor Black
            $EndTimeTF = Get-Date
            $durationTF = [math]::Round((New-TimeSpan -Start $StartTimeTF -End $EndTimeTF).TotalMinutes,2)
            Write-Host "Execution Time" $durationTF -ForegroundColor Green -BackgroundColor Black
            Write-Host ""
        }

    if ($ProxyPerHost)
        {
            RenameFileBackForAntiAffinity
        }

    if ($DHCP)
        {
            RenameFileBackForDHCP
        }

    if ($Workgroup)
        {
            RenameFileBackForWorkGroup
        } 
}

if (($Ubuntu -or $CentOS) -and !$Destroy -and !$ScaleDown){
    #Run the code for Linux Proxies
 
    if ($ProxyPerHost)
        {
            RenameFileForAntiAffinity 
        }

    if ($DHCP)
        {
            RenameFileForDHCP
        }

    if ($Workgroup)
        {
            RenameFileForWorkGroup
        }  

    $StartTimeTF = Get-Date
    LinuxProxyBuild
    Write-Host ""
    Write-Host ":: - Windows Proxies Deployed via Terraform - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeTF = Get-Date
    $durationTF = [math]::Round((New-TimeSpan -Start $StartTimeTF -End $EndTimeTF).TotalMinutes,2)
    Write-Host "Execution Time" $durationTF -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    $StartTimeTF = Get-Date
    AddVeeamProxy
    Write-Host ""
    Write-Host ":: - Windows Proxies Configured - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeTF = Get-Date
    $durationTF = [math]::Round((New-TimeSpan -Start $StartTimeTF -End $EndTimeTF).TotalMinutes,2)
    Write-Host "Execution Time" $durationTF -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    if ($ProxyPerHost)
        {
            RenameFileBackForAntiAffinity
        }

    if ($DHCP)
        {
            RenameFileBackForDHCP
        }

    if ($Workgroup)
        {
            RenameFileBackForWorkGroup
        } 
}

if ($Destroy -and !$ScaleDown){
    #Run the code to Remove Proxies 
    $StartTimeCL = Get-Date
    
    if ($ProxyPerHost)
        {
            RenameFileForAntiAffinity 
        }

    if ($DHCP)
        {
            RenameFileForDHCP
        }

    if ($Workgroup)
        {
            RenameFileForWorkGroup
        }  
    
    RemoveVeeamProxy
    Write-Host ""
    Write-Host ":: - Clearing Backup & Replication Server Configuration - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeCL = Get-Date
    $durationCL = [math]::Round((New-TimeSpan -Start $StartTimeCL -End $EndTimeCL).TotalMinutes,2)
    Write-Host "Execution Time" $durationCL -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    $StartTimeCL = Get-Date
    ProxyDestroy
    Write-Host ""
    Write-Host ":: - Destroying Proxies with Terraform - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeCL = Get-Date
    $durationCL = [math]::Round((New-TimeSpan -Start $StartTimeCL -End $EndTimeCL).TotalMinutes,2)
    Write-Host "Execution Time" $durationCL -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    if ($ProxyPerHost)
        {
            RenameFileBackForAntiAffinity
        }

    if ($DHCP)
        {
            RenameFileBackForDHCP
        }

    if ($Workgroup)
        {
            RenameFileBackForWorkGroup
        }       
}

if ($ScaleDown){
    #Run the code to Scale Down Proxies
    $StartTimeCL = Get-Date

    if ($ProxyPerHost)
        {
            RenameFileForAntiAffinity 
        }

    if ($DHCP)
        {
            RenameFileForDHCP
        }

    if ($Workgroup)
        {
            RenameFileForWorkGroup
        }  
    
    Write-Host ""
    Write-Host ":: - Scaling Down Proxies from Backup & Replication Server Configuration - ::" -ForegroundColor Green -BackgroundColor Black
    ScaleDownVeeamProxy
    $EndTimeCL = Get-Date
    $durationCL = [math]::Round((New-TimeSpan -Start $StartTimeCL -End $EndTimeCL).TotalMinutes,2)
    Write-Host "Execution Time" $durationCL -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    $StartTimeCL = Get-Date
    Write-Host ""
    Write-Host ":: - Scaling Down Proxies with Terraform - ::" -ForegroundColor Green -BackgroundColor Black
    
    if($Windows)
        {
            WindowsProxyBuild
        }

    if($Ubuntu -or $CentOS)
        {
            LinuxProxyBuild
        } 

    $EndTimeCL = Get-Date
    $durationCL = [math]::Round((New-TimeSpan -Start $StartTimeCL -End $EndTimeCL).TotalMinutes,2)
    Write-Host "Execution Time" $durationCL -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    if ($ProxyPerHost)
        {
            RenameFileBackForAntiAffinity
        }

    if ($DHCP)
        {
            RenameFileBackForDHCP
        }

    if ($Workgroup)
        {
            RenameFileBackForWorkGroup
        } 
}

Stop-Transcript

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

$host.ui.RawUI.WindowTitle = "AUTOMATION AND ORCHESTRATION COMPLETE"
Write-Host "Total Execution Time" $duration -ForegroundColor Green -BackgroundColor Black
Write-Host