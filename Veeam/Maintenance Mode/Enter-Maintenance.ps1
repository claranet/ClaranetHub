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
if( [System.IO.File]::Exists($_FILE) ) {
  log "State File already exists - remove it first!!"
  pause
  Exit 1
}


# Create new, empty state file
New-Item -Path $_FILE -Force | Out-Null

log "Load Jobs"
$JOBS = Get-VBRJob

# Save list of current jobs state (enabled/disabled)
log "Dump Job states to file"
$STATES = ( $JOBS | SELECT Id, Name, IsScheduleEnabled, @{N="IsSchedulable"; E={$_.IsSchedulable()}} )
$STATES | ConvertTo-Json | Out-File -FilePath $_FILE

# Stop All running jobs
log "Stop all Jobs"
if(-not $DryRun) { $JOBS | Stop-VBRJob -RunAsync }

# Disable all Jobs
# Jobs with non active automatic scheduler cannot be disabled
log "Disable all jobs"
if(-not $DryRun) { $JOBS | ?{ $_.IsSchedulable() } | Disable-VBRJob | Out-Null }

log "Finish"

pause 
