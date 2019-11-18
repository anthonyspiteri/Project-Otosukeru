﻿# Project Ōtosukēru 

![enter image description here](https://sociorocketnewsen.files.wordpress.com/2017/12/gp-41.png)

## Description
The aim of this project, is to have Veeam Proxies automtically deployed and configured for ephemeral use by Veeam Backup & Replication jobs. It has the ability to deploy Veeam Backup Proxy VMs to vSphere and configures them in Veeam Backup & Replication and also the ability to remove the configuration and destory the VMs. A pre and post script can be configured within the Veeam Job and run everytime the job is executed.

There is a master PowerShell script that executes all the code as does the following:

- Connects to a Veeam Backup & Replication Server
- Gets all Backup Jobs and derives the number of VMs total being backed up
- Option exists for HCI deployments to set Proxy count to number of hosts
- Works out how many Veeam Proxies to deploy and sets that as a proxy count value
- Executes Terraform apply using the proxy count value
- Terraform deploys Proxies VM to vCenter, configures VM with name and static IP (DHCP Optional), and adds GustOS to domain
- PowerShell adds Proxies to Backup & Replication
- PowerShell then removes Proxies from Backup & Replication
- Destroys the Proxy VMs with Terraform

## Requirements

1. Download [Terraform](https://releases.hashicorp.com/terraform/0.11.7/) (tested version 0.11.7 - 0.12.x will not work) binary to your workstation. Ensure it's set in [system environmental variables](https://learn.hashicorp.com/terraform/getting-started/install.html)
2. Terraform vSphere Provider called from 'main.tf'
3. Pre configured Windows (2019 Server Core Preferred ) or Linux (Ubuntu 18.04 LTS Preferred with CentOS 7 also tested) Template accessible from vCenter
4. For Linux Template, Firewall must be enabled otherwise Terraform deployment will fail
5. Update the VMware and Linux Template credentials required to communicate to vCenter and modify in config.json
6. Update the variable values in the 'terraform.tfvars' file under proxy_windows and proxy_linux
7. Update CentOS and Ubuntu values in the 'maps.tf' file under proxy_linux
8. Update path in 'pre.bat' and 'post.bat

* Veeam Backup & Replication 9.5 Update 4b tested and supported for Windows Proxy Only
* Veeam Backup & Replication v10 readiness with support for Windows and Linux Proxy
* Should be run from VBR Server to ensure Console Versions are compatible
* Require Execution Policy set to Bypass - Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

#### Version 1.0
> 0.2 - First pre release for testing 

> 0.4 - Added support for Linux Server to be added and removed to VBR Inventory in preperation for v10 Proxy PowerShell
      - Added Error Checking on VBR Connection that will exist if not sucessfull on conneciton

> 0.9 - Added support for Ubuntu or CentOS (Ubuntu default now in variable examples) 
      - Added remote-exec Terraform entry to add port 2500 to Linux FW in readiness for v10
      - Added error checking for VBR connectivity, Job VM Count and Terraform deployment issues
      - Added experimental support for -SetProxyCount parameter

> 0.9.5 - Created new parameters that deploy a CentOS or Ubuntu based Proxy depending on the flag used. All configuration for either distro is contained in Terraform MAP variables declared in the variables.tf file of proxy_linux. This allows for the deployment of Windows, Ubuntu or CentOS based Proxies

> 0.9.5.1 - Seperated MAP variables out to self contained declaration file for easier editing

> 0.9.5.2 - Added error checking for Proxy Server VBR configuration when adding managed server

> 0.9.5.3 - Added random number element to Proxy VM and Machine Name to allow overlapping instances to be run (allowing for future DHCP support) and not have conflicts

> 0.9.6 - Added ability to calculate Proxy count based on Host Number mainly for HCI deployments. This will look at the number of hosts, set the Proxy count to that and then deploy the Proxies and a vSphere Anti-Affinity rule ensuring all Proxies are started on seperate hosts.

> 0.9.7 - Completed DHCP option for Proxy Deployment. Default remains static IP configuration as dictated by network variables in terraform.tfvars files. Tested with Windows and Ubuntu VM templates.

> 1.0 - Completed support for VBR v10 Linux Proxy Configuration (tested against BETA2)

## Getting Started

Ensure all configuration variables are set as per requirements and as per below.

    PARAMETER Windows - Will deploy Windows Template for Veeam Proxy VMs and configure Veeam Server
    PARAMETER Ubuntu - Will deploy Ubuntu Template for Veeam Proxy VMs and configure Veeam Server
    PARAMETER CentOS - Will deploy CentOS Template for Veeam Proxy VMs and configure Veeam Server
    PARAMETER Destroy - Will Destroy configuration from Veeam Server and destroy Proxy VMs in combination with -Windows or -Ubuntu or -CentOS
    PARAMETER ProxyPerHost - Will set number of Proxyies to number of hosts in vCenter Cluster
    PARAMETER DHCP - Will use DHCP to configure Veeam Proxy VM networking

    EXAMPLE - PS C:\>deploy_otosukeru.ps1 -Windows
    EXAMPLE - PS C:\>deploy_otosukeru.ps1 -Ubuntu
    EXAMPLE - PS C:\>deploy_otosukeru.ps1 -CentOS
    EXAMPLE - PS C:\>deploy_otosukeru.ps1 -Windows -Destroy
    EXAMPLE - PS C:\>deploy_otosukeru.ps1 -CentOS -ProxyPerHost
    EXAMPLE - PS C:\>deploy_otosukeru.ps1 -Ubuntu -DHCP

To Create and Configure Proxies:

    ./deploy_otosukeru.ps1 -Windows
    ./deploy_otosukeru.ps1 -Ubuntu
    ./deploy_otosukeru.ps1 -CentOS

or to run from Veeam Backup Job

    ./pre.bat 

To Destroy and Destroy Proxies:

    ./deploy_otosukeru.ps1 -Windows -Destroy
    ./deploy_otosukeru.ps1 -Ubuntu -Destroy
    ./deploy_otosukeru.ps1 -CentOS -Destroy

or to run from Veeam Backup Job

    ./post.bat 
    
Modification can be made to pre/post script. Requires editing of path relative to local environment. Example execution for Windows and Linux contained. If you have a HCI configuration you might want to look at -ProxyPerHost as an additional parameter. For DHCP configuration you need to add -DHCP as an additional parameter.
    
## Configuration

## config.json Breakdown
All of the variables are configured in the config.json file. Nothing is required to be changed in the main depply script.

    {
    "LinuxProxy": {
		    "Username": "root",
		    "LocalUsername":"root",
		    "LocalPasswordUbuntu":"password$12"
             "LocalPasswordCentOS":"password$12"
		},
    
    "VBRDetails": {
		    "Server":"TPM03-VBR01.AperatureLabs.biz",
		    "Username":"APLABS\\service.veeam",
		    "Password":"password$12"
	    }
    }

## terraform.tfvars Breakdown
All variables are configured in the terraform.tfvars file and passed through to the TF configuration files. There is one config file for Windows and Linux Proxy deployment. Each contained in the repective folders. 

### vCenter connection

    vsphere_vcenter = "vc03.aperaturelabs.biz"
    vsphere_user = "administrator@vsphere.local"
    vsphere_password = "PASSWORD"
    vsphere_unverified_ssl = "true"

### VM specifications Windows (proxy_windows)

The following variables can be adjusted dependant on installation vSphere platform. The ones to look out for that could cause issues is the vm_firmware and vm_tags variables. The vm_template and vm_firmware need to be noted depending on Windows or Linux configuration.

    vsphere_datacenter = "VC03"
    vsphere_vm_folder = "TPM03-AS"
    vsphere_vm_resource_pool ="TPM03-AS"
    vsphere_vm_template = "TPM03-AS/WIN2K19-TEST"
    vsphere_vm_firmware = "efi"
    vsphere_cluster = "MEGA-03"
    vsphere_vcpu_number = "2"
    vsphere_memory_size = "8192"
    vsphere_datastore = "vsanDatastore"
    vsphere_port_group = "TPM03-730"
    vsphere_ipv4_address = "10.0.30.210"
    vsphere_ipv4_netmask = "24"
    vsphere_ipv4_gateway = "10.0.30.1"
    vsphere_dns_server1 = "10.0.0.2"
    vsphere_dns_server2 = "10.0.0.3"
    vsphere_domain = "aperaturelabs.biz"
    vsphere_time_zone = "UTC"
    vsphere_vm_password ="Veeam1!"
    vsphere_tag_category ="TPM03"
    vsphere_tag_name ="TPM03-NO-BACKUP"

### VM specifications Linux (proxy_linux)

The following variables can be adjusted dependant on installation vSphere platform. The ones to look out for that could cause issues is the vm_firmware and vm_tags variables. The vm_firmware need to be noted depending on Windows or Linux configuration.

    vsphere_datacenter = "VC03"
    vsphere_vm_folder = "TPM03-AS"
    vsphere_vm_resource_pool ="TPM03-AS"
    vsphere_vm_firmware = "bios"
    vsphere_cluster = "MEGA-03"
    vsphere_vcpu_number = "4"
    vsphere_memory_size = "8192"
    vsphere_datastore = "vsanDatastore"
    vsphere_port_group = "TPM03-730"
    vsphere_ipv4_address = "10.0.30.210"
    vsphere_ipv4_netmask = "24"
    vsphere_ipv4_gateway = "10.0.30.1"
    vsphere_dns_server1 = "10.0.0.2"
    vsphere_dns_server2 = "10.0.0.3"
    vsphere_domain = "aperaturelabs.biz"
    vsphere_time_zone = "UTC"
    vsphere_tag_category ="TPM03"
    vsphere_tag_name ="TPM03-NO-BACKUP"

### Proxy Configuration 

The varibales below dictate the number of nodes (if run outside of PowerShell Proxy Logic), the first three octects of the IP Subnet and then the starting host address of proxies. The names and IP addresses of Proxies are incremented based on the number of Proxies being deployed. The Linux Distro variable is used as a default (if run outside of PowerShell Proxy Logic) but is setup through the -CentOS or Ubuntu parameter

    vpshere_linux_distro ="centos"
    vsphere_proxy_number = "3"
    vsphere_ipv4_address_proxy_network = "10.0.30."
    vsphere_ipv4_address_proxy_host ="210"

## maps.tf Breakdown (proxy_linux)
To make Linux deployment more streamlined, there is a seperate maps.tf file from which to set specific distro variables. The MAPs are then used depending on the vsphere_linux_distro variable that is set in 'terraform.tfvars' (if run outside of PowerShell) or set at the time of Terraform apply. Example below is for Ubuntu and CentOS and sets remote_exec command for FW rules 2500, the template location and the template password.

    variable "remote_exec" {
        default = {
        ubuntu = "sudo ufw allow from any to any port 2500 proto tcp"
        centos = "firewall-cmd --zone=public --add-port=2500/tcp --permanent; firewall-cmd --reload"
        }
    }
    variable "linux_template" {
        default = {
        ubuntu = "TPM03-AS/TPM03-UBUNTU-ROOT"
        centos = "TPM03-AS/TPM03-CENTOS7-TEMPLATE"
        }
    }
    variable "linux_password" {
        default = {
        ubuntu = "password$12"
        centos = "Veeam1!"
        }
    }

## To Do

 - [X] Complete option for Linux Proxy deployment and configuration (waiting for PowerShell commands in v10)
 - [X] Add option to choose DCHP or Static IP Allocation
 - [X] Add ability to scale Proxies outside of pre and post job scripts
 - [X] Add error checking to ensure correct exit conditions
 - [ ] Add option to not join GuestOS to domain
 - [ ] Fix compatability issues with Terraform 0.12.x - main issue is JSON output not being correct format for PowerShell import
 - [ ] Improve basic Proxy sizing logic
 - [ ] Create new feature to scale Proxies up or down once initial deployment has been completed

 ## ✍ Contributions

We welcome contributions from the community! We encourage you to create [issues](https://github.com/VeeamHub/veeam-proxy-autodeploy/issues/new/choose) for Bugs & Feature Requests and submit Pull Requests. For more detailed information, refer to our [Contributing Guide](CONTRIBUTING.md).

## 🤝🏾 License

* [MIT License](LICENSE)

## 🤔 Questions

If you have any questions or something is unclear, please don't hesitate to [create an issue](https://github.com/VeeamHub/veeam-proxy-autodeploy/issues/new/choose) and let us know!