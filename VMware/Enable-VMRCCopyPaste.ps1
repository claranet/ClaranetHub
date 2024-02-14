<#
.SYNOPSIS
Enable Copy&Paste for vm remote console to given virtual machines

.DESCRIPTION
Set VM advanced configurator to enable copy & paste. Note that the Vm should be powered off before

.NOTES
  Name: Enable-VMRCCopyPaste.ps1
  Author: Martin Weber (martin.weber@de.clara.net)
  Create: 14.02.2024
  Modified: -

.PARAMETER VM
List of VMs to work on

.EXAMPLE
Get-VM "my-vm" | ./Enable-VMRCCopyPaste.ps1

.EXAMPLE
# Step by step
$vm = Get-VM "my-vm"
Stop-VM $vm
./Enable-VMRCCopyPaste.ps1 $vm
Start-VM $vm

.EXAMPLE
# Full Pipe...
Get-VM "my-vm" | Stop-VM | ./Enable-VMRCCopyPaste.ps1 | Start-VM

#>

param(
  [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
  [PSObject[]]$VM
)

begin {
  $vmConfigSpec = new-object VMware.Vim.VirtualMachineConfigSpec

  $vmConfigSpec.ExtraConfig += new-object vmware.vim.optionvalue
  $vmConfigSpec.ExtraConfig[-1].key = "isolation.tools.copy.disable"
  $vmConfigSpec.ExtraConfig[-1].value = "false"
  $vmConfigSpec.ExtraConfig += new-object vmware.vim.optionvalue
  $vmConfigSpec.ExtraConfig[-1].key = "isolation.tools.paste.disable"
  $vmConfigSpec.ExtraConfig[-1].value = "false"
  $vmConfigSpec.ExtraConfig += new-object vmware.vim.optionvalue
  $vmConfigSpec.ExtraConfig[-1].key = "isolation.tools.setGUIOptions.enable"
  $vmConfigSpec.ExtraConfig[-1].value = "true"

}

process {
  $VM.ExtensionData.ReconfigVM_Task($vmConfigSpec) | Out-Null
  # fetch updated VM and return
  Get-VM $VM
}

end {  }
