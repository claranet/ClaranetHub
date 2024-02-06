# VMware Duplicate DiskUUID

DISCLAIMER Use it in your own risk!

Details:
* https://kb.vmware.com/s/article/2006865

Official from VMware KB
> This issue may occur when multiple virtual machines are deployed within a
short period of time from the same template to different hosts. The backup
application fails because some third party backup applications require the
virtual machines to have unique UUIDs.

The workaround of VMware required a shutdown of the VM. This Script did it
on-the-fly without reboot.

It changes the Disk UUID using PowerShell and VirtualDiskManager and triggers a
VM vMotion. Take Note that all VM/Host rules should be turned off during this
changes.

# Identify disks with duplicate UUIDs

This command collects all Disks and group them by disk UUID
```powershell
Get-VM | Get-HardDisk `
  | Select @{N='Disk';E={$_}}, `
           @{N='Uuid';E={$_.ExtensionData.Backing.Uuid}}, `
           @{N='ParentUuid';E={$_.ExtensionData.Backing.Parent.Uuid}} `
  | Group-Object -Property Uuid | ?{ $_.Count -gt 1 }
```

# get rid of duplicate UUID

```powershell
# Collect Rule states of each cluster and save to json file and disable rules
Get-Cluster | Get-DrsVMHostRule `
  | Select Name, `
           @{N="Cluster"; E={$_.Cluster.Name}}, `
           @{N="RuleUuid"; E={$_.ExtensionData.RuleUuid}}, `
          Enabled `
  | ConvertTo-JSON > rules.json

Get-Cluster | Get-DrsVMHostRule | Set-DrsVMHostRule -Enabled:$False

# Change DISK UUIDs
Get-VM | ./Change-DiskUUID.ps1

# Load json file and re-enabled rules
Get-Content rules.json | ConvertFrom-Json | ?{ $_.Enabled } | %{
  Get-DrsVMHostRule -Cluster $_.Cluster -Name $_.Name | Set-DrsVMHostRule -Enabled:$True
}
```


# Thanks

Thanks to Milla - https://blog.milla-online.de/duplicate-disk-uuids-and-how-to-get-rid-of-it-hopefully

# Changelog

* 09.03.2023 - Only trigger vMotion one time for VM if a VM has multiple disks with multiple UUID
* 09.03.2023 - Skip VM from Process if VM has Snapshots. Change of DiskUUI wont work here
* 10.03.2023 - Improve Logging - Write logs to file and dump duplicate disks to json
* 10.03.2023 - Improve Logging - Write details if set new uuid did not work
* 10.03.2023 - Skip VMs with linked HardDisks



```powershell
$VM = Get-VM "<my vm>"
$Snapshot = $VM | New-Snapshot -Name "BASE"
New-VM -Name "$($VM.Name) - Linked Clone" -VM $VM -VMHost $VM.VMHost -LinkedClone -ReferenceSnapshot $Snapshot
 
Get-VM -Name "$($VM.Name)*"| Get-HardDisk | Select @{N='Name';E={$_.Parent.Name}}, @{N='Uuid';E={$_.ExtensionData.Backing.Uuid}}
```
