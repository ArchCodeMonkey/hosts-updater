<#
   .SYNOPSIS
   This script updates the hosts file with the current IP address of running Hyper-V virtual machines

   .PARAMETER VMName
   The name of a Hyper-V virtual machine to start (optional)

   .NOTES
   The Hyper-V Default Switch is recreated every time the host machine is restarted.
   The switch uses a different IP address range each time which causes problems with using
   the hosts file to create local testing domains that point to the virtual machine.
#>

#Requires -Version 5.0
#Requires -RunAsAdministrator
#Requires -Modules Hyper-V


using namespace Microsoft.HyperV.PowerShell
using namespace System.IO
using namespace System.Net.Sockets


param ([string]$VMName)

Set-StrictMode -Version Latest


# The location of the hosts file
$HOSTS_FILE = "C:\Windows\System32\drivers\etc\hosts"

# The location of the template file to use when generating a new hosts file
$HOSTS_TEMPLATE = "C:\Windows\System32\drivers\etc\hosts.template"


function Get-VMIPAddress([string] $MachineName)
{
   <#
      .SYNOPSIS
      This method determines the IP address of a virtual machine

      .PARAMETER MachineName
      The name of the virtual machine

      .OUTPUTS
      The IP address of the virtual machine

      .NOTES
      If the virtual machine has only just booted then it can take a while to start reporting its IP address.
      Depending on the startup load it may be neccessary to give it more time to stabilise.

      Without the "linux-cloud-tools-virtual" package a Linux guest may not be able to report its IP address.
   #>

   $MAX_RETRY = 15

   Write-Host "Querying virtual machine '$MachineName' for IP Address"

   $IPAddress = ''
   $RetryCount = 0

   While ([string]::IsNullOrEmpty($IPAddress) -and $RetryCount -lt $MAX_RETRY)
   {
      # NOTE: Use InterNetworkV6 for IPv6 addresses
      $IPAddress = (Get-VMNetworkAdapter -VMName $MachineName).IPAddresses | Where-Object { ([IPAddress]$_).AddressFamily -eq [AddressFamily]::InterNetwork }

      If ([string]::IsNullOrEmpty($IPAddress))
      {
         Write-Host "Waiting for IP Address..."
         Start-Sleep -s 1
         $RetryCount++
      }
   }

   return $IPAddress
}


If ( -not [string]::IsNullOrEmpty($VMName))
{
   Try
   {
      $TargetVM = Get-VM -Name $VMName -ErrorAction Stop
   }
   Catch [VirtualizationException]
   {
      Write-Host "Problem locating virtual machine '$VMName'"
   }

   If ($TargetVM -ne $null)
   {
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
   }
}

# NOTE: Using .NET File methods as PowerShell methods have been unreliable
$TemplateData = [File]::ReadAllText($HOSTS_TEMPLATE)

Get-VM | Where-Object { $_.State -eq [VMState]::Running } | ForEach-Object {
   $MachineName = $_.Name
   $IPAddress = Get-VMIPAddress($MachineName)

   If ( -not [string]::IsNullOrEmpty($IPAddress))
   {
      Write-Host "Adding IP '$IPAddress' for virtual machine '$MachineName' to hosts file"
      $TemplateData = $TemplateData -Replace "#$MachineName#", $IPAddress
   }
   Else
   {
      Write-Host "Could not determine IP Address for virtual machine '$MachineName'"
   }
}

[File]::WriteAllText($HOSTS_FILE, $TemplateData)
