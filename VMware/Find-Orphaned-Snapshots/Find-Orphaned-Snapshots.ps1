<#
.SYNOPSIS
  Find orphaned vmware vcloud director snapshots
.DESCRIPTION
  You have to login to CIServer and VIServer!
  This script collect informations of vmare CIVM and look up
  if it has a snapshot in vCloud Director or in vCenter.
  
  This Script only take care about vCloud Director snapshots in vCenter! 

.PARAMETER CIVM
    CIVM to Process
.OUTPUTS
  List of Name, Org, OrgVDC, CISnapshot, VISnapshot
.NOTES
  Version:        1.0
  Author:         Martin Weber
  Creation Date:  26.06.2023
  Purpose/Change: Initial script development
  
.EXAMPLE
  Get-Org my-org | Get-CIVM | ./Find-Orphaned-Snapshots.ps1

  Get-Org my-org | Get-CIVM | ./Find-Orphaned-Snapshots.ps1 | ?{$_.VISnapshot -or $_.CISnapshot }
#>

param(
  [Parameter(ValueFromPipeline=$true)] 
  $CIVM
)

process {

  function hasCISnapshot($vm) {
    return ($vm | Get-CIView).GetSnapshotSection().Snapshot -ne $Null
  }

  function hasVISnapshot($vm) {
    $vsphereVMView = Get-View -RelatedObject $vm.ExtensionData
    $vivm = Get-VIObjectByVIView $vsphereVMView
    $snapshots = $vivm | Get-Snapshot | ?{ $_.Name -like "user-*-snapshot*"}
    return $snapshots.Length -gt 0
  }

  Foreach ($_civm in $CIVM) {
    $_civm | Select Name, Org, OrgVdc, @{N="CISnapshot";E={hasCISnapshot($_)}}, @{N="VISnapshot";E={hasVISnapshot($_)}}
  }

}
