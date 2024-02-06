<#
.SYNOPSIS
Recreate a BIOS UUID for given VMs

.DESCRIPTION
Cloning VMs or test restores of them can result in some errors because
some services required a unique BIOS UUID.

For Example: Adding VEEAM Linux Agent requires a unique BIOS UUID. On
adding a restored VM as agent, it will run into a failure.

.NOTES
  Name: New-VMBiosUUID.ps1
  Author: Martin Weber (martin.weber@de.clara.net)
  Create: 06.02.2024
  Modified: -

.PARAMETER VM
List of VMs to work on

.EXAMPLE
...

#>

param(
  [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
  [PSObject[]]$VM
)

BEGIN {}
PROCESS {

  $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
  $spec.uuid = (New-Guid).Guid
  
  $VM.Extensiondata.ReconfigVM_Task($spec)

}
END {}