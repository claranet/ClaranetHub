param(
  [switch]$DryRun=$False
)
Import-Module Veeam.Backup.PowerShell

Function log($message) {
  $timestamp = Get-Date -Format "yyyy-MM-ss hh:mm:ss"
  Write-Host "$($timestamp) - $($message)"
}

if($DryRun) { log "DRY RUN - NOTHING WILL CHANGE" }

$_FILE = "$PSScriptRoot/job_states.json"
if( -not [System.IO.File]::Exists($_FILE) ) {
  log "Missing state file... Cancle"
  pause
  Exit 1
}

log "Load list of Last Job States"
$STATES = Get-Content $_FILE | ConvertFrom-Json

log "Enable all needed Jobs"
$JOBS = Get-VBRJob -Name ($STATES|?{-not $_.Proxy -and $_.IsScheduleEnabled}).Name
if(-not $DryRun) { $JOBS | Enable-VBRJob | Out-Null }

log "Retry Failed Backup jobs" 
if(-not $DryRun) { $JOBS | ?{ $_.GetLastResult() -eq "Failed" } | Start-VBRJob -RunAsync -RetryBackup }

Remove-Item -Path $_FILE

log "Finish"
pause 
