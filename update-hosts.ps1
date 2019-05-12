<#
   .SYNOPSIS
   This script updates the hosts file with the current IP address of a Hyper-V virtual machine

   .PARAMETER VMName
   The name of the Hyper-V virtual machine 

   .NOTES
   The Hyper-V Default Switch is recreated every time the host machine is restarted.
   The switch uses a different IP address range each time which causes problems with using
   the hosts file to create local testing domains that point to the virtual machine.
#>

#Requires -Version 5.0
#Requires -RunAsAdministrator
#Requires -Modules Hyper-V


using namespace Microsoft.HyperV.PowerShell
using namespace System.Net.Sockets


param ([Parameter(Mandatory=$true)][string]$VMName)


# The location of the hosts file
$HOSTS_FILE = "C:\Windows\System32\drivers\etc\hosts"

# The location of the template file to use when generating a new hosts file
$HOSTS_TEMPLATE = "C:\Windows\System32\drivers\etc\hosts.template"


$TargetVM = Get-VM -Name $VMName

If ($TargetVM.State -eq [VMState]::Off -or $TargetVM.State -eq [VMState]::Saved)
{
   Write-Host "Starting virtual machine '$VMName'"
   Start-VM -Name $VMName
}
ElseIf ($TargetVM.State -eq [VMState]::Paused)
{
   Write-Host "Resuming paused virtual machine '$VMName'"
   Resume-VM -Name $VMName
}

$Heartbeat = $TargetVM.HeartBeat

While (($Heartbeat -ne [VMHeartbeatStatus]::OkApplicationsHealthy) -and ($Heartbeat -ne [VMHeartbeatStatus]::OkApplicationsUnknown))
{
   Write-Host "Waiting for the virtual machine to finish booting..."
   Start-Sleep -s 1
   $Heartbeat = $TargetVM.HeartBeat
}

Start-Sleep -s 1

# NOTE: Use InterNetworkV6 for IPv6 addresses
$VMIPAddress = (Get-VMNetworkAdapter -VMName $VMName).IPAddresses | Where-Object { ([IPAddress]$_).AddressFamily -eq [AddressFamily]::InterNetwork }

If ($VMIPAddress -ne $null)
{
   Write-Host "Generating hosts file with virtual machine IP '$VMIPAddress'"
   (Get-Content -Path $HOSTS_TEMPLATE) | ForEach-Object { $_ -Replace "^#$VMName#", $VMIPAddress } | Out-File $HOSTS_FILE
}
