# Hosts file updater

The Hyper-V "Default Switch" provides an out of the box virtual network with NAT enabled to simplify creation of basic virtual machines. Unfortunately, it is recreated every time the host machine is restarted and uses a completely different IP address range each time. This causes problems when attempting to use the Windows *hosts* file to create entries that point to a test server running on a virtual machine.

This script updates the *hosts* file with the current IP address of any running Hyper-V virtual machines. This allows creating entries to enable access to local development web sites from the browser or SSH access to the virtual server without having to first identify the current IP address.

**NOTE:** The virtual machine must be running for it to have an IP address, this script can optionally attempt to start a specified virtual machine if it is not already active.

## Setup

Make a copy of the current *hosts* file and call it `hosts.template`. Update this file with any required testing domains using the following format (see the included `hosts.template` file for a usage example).

```ini
#{VM_NAME}# myservername
#{VM_NAME}# mytestingsite.local
```

**NOTE:** If the virtual machine contains a Linux guest then the `linux-cloud-tools-virtual` (Ubuntu) or `hyperv-daemons` (CentOS) package may be required to enable interogating the virtual machine for its IP address.

## Usage

By default, this script will look for any currently running Hyper-V virtual machines and update the *hosts* file with the IP address, providing there is a corresponding entry in the `hosts.template` file. It requires administrator privileges to run and also has not been digitally signed, which may conflict with the system PowerShell Execution Policy.

The script optionally takes a virtual machine name as a parameter, if the virtual machine name contains spaces then it must be enclosed in quotes. 

The simplest way to manage these requirements is to create a shortcut to the script in a convenient location. In the shortcut properties, select the *"Shortcut"* tab and enter the following into the *"Target"* field.

```
powershell.exe -ExecutionPolicy Bypass -File "path\to\script\update-hosts.ps1" -VMName "Virtual Machine Name"
```

On the same tab, click the *"Advanced..."* button and select the *"Run as administrator"* checkbox.

This shortcut can then be used to run the script and it will trigger a UAC prompt to allow administor privileges.

**NOTE:** Antivirus software can block access to the *hosts* file to help prevent malware from making malicious changes. It will be neccessary to disable any such feature to allow this script to execute successfully.
