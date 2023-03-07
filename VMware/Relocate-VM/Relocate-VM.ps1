<#
.SYNOPSIS
Relocate VM to random ESXi on Cluster

.DESCRIPTION
This script relocate given VMs to another random ESXi in the same Cluster.

It can be Usefull for some errors, for example backups, if a VM need to
relocate to another VMHost.

.NOTES
  Name: Relocate-VM.ps1
  Author: Martin Weber (martin.weber@de.clara.net)
  Create: 07.03.2023
  Modified: -

.PARAMETER VM
  List of VMs returned by Get-VM

.EXAMPLE
  Get-VM -Name "*backup*" | Relocate-VM.ps1
#>

param(
  [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
  [PSObject[]]$VM
)

PROCESS {
  Function log($message) {
    $date = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
    Write-Host "$($date) - $($message)"
  }

  ForEach($_VM in $VM) {
    $_VM = Get-VM $_VM
    log "Relocate VM: $($_VM.Name)"
    $Cluster = $_VM | Get-Cluster
    log "Detected Cluster: $($Cluster.Name)"
    $CurrentHost = $_VM | Get-VMHost
    log "Curent Host: $($CurrentHost.Name)"
    $Sibling = $Cluster | Get-VMHost | ?{ $_ -ne $CurrentHost } | Get-Random
    log "Selected Sibling: $($Sibling.Name)"
    log "Move VM $($_VM.Name) to $($Sibling.Name)"
    Move-VM -VM $VM -Destination $Sibling | Out-Null
  }
}

END {
  log "Finish"
}
