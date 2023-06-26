# Find oprhaned vcloud snapshots

In some cases snapshots in vcenter are still available after remove them in vcloud director.

This script can help to find such orphaned snapshots.

## Usages

```powershell
Get-Org myorg | Get-CIVM | ./Find-Orphaned-Snapshots.ps1

Get-Org myorg | Get-CIVM | ./Find-Orphaned-Snapshots.ps1 | ?{$_.VISnapshot -or $_.CISnapshot }
```