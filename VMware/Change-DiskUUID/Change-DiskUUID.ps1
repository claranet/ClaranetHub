<#
.SYNOPSIS
This Script changes Disk UUIDs of VMs

.DESCRIPTION
During a problem in the past, some VMs can have disks with identicakl UUIDs
(https://kb.vmware.com/s/article/2006865). This make problems on future usability
of the VMs.

This Scrtip collect the VMs and Disk, create a new UUID, change it and triggers
a vMotion. In this way, the disk UUID can change on the fly without
downtime.

Thanks to Milla - https://blog.milla-online.de/duplicate-disk-uuids-and-how-to-get-rid-of-it-hopefully

.NOTES
  Name: Change-DiskUUID.ps1
  Author: Martin Weber (martin.weber@de.clara.net)
  Create: 09.03.2023
  Modified: -

.PARAMETER VM
List of VMs to work on

.PARAMETER LogLevel
Loglevel - TRACE, DEBUG, INFO, WARNING, ERROR

.PARAMETER TestRun
Do not change anything

.EXAMPLE
Get-VM | ./Change-DiskUUID.ps1

Change the UUID of all VMs in the connected vCenter

.EXAMPLE
Get-VM -Name 'db*' | ./Change-DiskUUID.ps1

Change the UUID of given VMs in the connected vCenter

#>

param(
  [ValidateSet('TRACE','DEBUG','INFO', 'WARNING', 'ERROR')]
  [string]$LogLevel = "INFO",
  [switch]$TestRun,
  [Parameter(Mandatory, ValueFromPipeline)]
  [PSObject[]]$VM
)

begin {
  enum LogLevel { TRACE; DEBUG; INFO; WARNING; ERROR }
  Function log() {
    param( [string]$Message, [LogLevel]$Level )
    $minLevel = [LogLevel]$LogLevel

    if([int]$Level -lt [int]$minLevel) { return }
    $date = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
    $logLine = "[$($Level)] $($date) - $Message"
    if($Level -eq [LogLevel]"ERROR") {
      Write-Host -ForegroundColor Red $logLine
    } else {
      Write-Host $logLine
    }
  }
  
  Function Generate-DiskUUID() {
    # Generate a new UUID
    # if a Olduuid is given, the first three parts will be kept for new one
    param(
      [string]$OldUuid = ""
    )
    $newUuid = (New-Guid).Guid

    if($oldUuid) {
      log -Level TRACE "Keep parts of old UUID: $($oldUuid)"
      log -Level TRACE "Generated UUID: $($newUuid)"
      $tmpOldUuid = $oldUuid.Split("-")
      $tmpNewUuid = $newUuid.Split("-")
      $tmpNewUuid[0] = $tmpOldUuid[0]
      $tmpNewUuid[1] = $tmpOldUuid[1]
      $tmpNewUuid[2] = $tmpOldUuid[2]
      $newUuid = $tmpNewUuid -join "-"
    }
    log -Level TRACE "FINAL NEW UUID: $($newUuid)"
    return $newUuid
  }

  Function Trigger-VMotion() {
    # Trigger a VM vMotion to another ESXi in the Cluster
    # Please note, this is will not chack affinity rules...
    param( $VM )
    $srcHost = $VM | Get-VMHost
    $vmCluster = $srcHost | Get-Cluster
    $dstHost = $vmCluster | Get-VMHost | ?{ $_ -ne $srcHost } | Get-Random

    log -Level INFO "Move VM $($VM.Name) from $($srcHost) to $($dstHost)"
    if(-not $TestRun) {
      Move-VM -VM $VM -Destination $dstHost -Confirm:$False | Out-Null
    }
  }

  # get the VirtualDiskManager
  $vdm = Get-View -Id (Get-View ServiceInstance).Content.VirtualDiskManager

  # Fetch all disks in the vCenter
  # Wen need all, it doesn't matter on which VMs we like work on
  log -Level INFO "Collect all Disks (will take a while)"
  $allDisks = Get-VM | Get-HardDisk
  $allDiskUUIDs = $allDisks.ExtensionData.Backing.Uuid
  # Collect duplicate UUIDs
  $duplicateDiskUUIDs = ($allDiskUUIDs | Group-Object | ?{ $_.Count -gt 1}).Name
}

process {
  # This part wil lbe process for every VM on $VM input

  # fetch VM disks which UUID are duplictaed
  $disksToWorkOn = $VM | Get-HardDisk | ?{ $_.ExtensionData.Backing.Uuid -in $duplicateDiskUUIDs }

  ForEach($disk in $disksToWorkOn) {
    $datacenter = $disk.Parent | Get-Datacenter

    $oldUuid = $disk.ExtensionData.Backing.Uuid
    log -Level DEBUG "Old UUID: $($oldUuid)"
    $newUuid = Generate-DiskUUID -OldUuid $oldUuid
    log -Level DEBUG "New UUID: $($newUuid)"
    if($newUuid -in $allDiskUUIDs) {
      # Log error if the generated UUID still exists
      # and continue with next
      log -Level ERROR "DISK UUID already exists"
      continue
    }
    log -Level INFO "Change $($VM.Name) Disk UUID from $($oldUuid) to $($newUuid)"

    # Format the UUID to required Format
    $newUuid = ($newUuid.Replace("-",'') -replace '(..)','$1 ').Trim(" ")
    $newUuid = $newUuid.Substring(0,23) + "-" + $newUuid.Substring(24,23)
    log -Level TRACE "Converted UUID: $($newUuid)"

    if(-not $TestRun) {
      # Set the new UUID to the disk
      $vdm.SetVirtualDiskUuid($disk.ExtensionData.Backing.FileName,$datacenter.Id, $newUuid)
    }
    # Finally trigger a vMotion to the VM
    Trigger-VMotion -VM $disk.Parent
  }

}
