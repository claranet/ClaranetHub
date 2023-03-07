
Import-Module Veeam.Backup.PowerShell -WarningAction Ignore

# Get all proxies and create regexes for matching log entries
$proxies = Get-VBRViProxy
$proxies_regex = ('(?i)(' + (($proxies.Name | ForEach {[regex]::escape($_)}) -join "|") + ')') -replace "\\\*", ".*"
$harddisk_regex = "(?i)(Hard disk\s+\d+)"

# Create empty array to hold results
$proxy_tasks = @()

# Get currently active backup sessions
$active_sessions = Get-VBRBackupSession | ?{$_.JobType -eq "Backup" -and $_.State -eq "Working"} | Sort JobName, Name
if (!$active_sessions) { Write-Host -ForegroundColor Red "No active backup sessions found!";Break }

foreach ($session in $active_sessions) {
    $tasks = $null = $session.GetTaskSessionsbyStatus("InProgress")  # Get all active tasks
    foreach ($task in $tasks) {
        $logs = $task.Logger.GetLog().UpdatedRecords # Get all logs for current task
        $proxy_logs = $null = $logs.Title | Select-String -Pattern $proxies_regex # Select all log lines that mention a proxy server
        $active_task_logs = $null = $logs | ?{$_.Status -eq "ENone"} # Select log entries that are in progress (exist but no completion status)
        foreach ($log_entry in $active_task_logs) {
            # If active log task includes "Hard disk XX" then its using a proxy, find the matching proxy log entry and grab the proxy name
            if ($log_entry.Title -match $harddisk_regex) {
                $harddisk = $matches[1]
                if (($proxy_logs | Select-String -Pattern $harddisk) -match $proxies_regex) {
                    # Insert collected info into an array
                    $proxy_tasks += New-Object -TypeName PSObject -Property (@{Proxy=$matches[1];Job=$session.JobName;VMname=$task.Name;Disk=$log_entry.Title;Progress=$log_entry.Description})
                }
            }
        }
    }
}
# Sort and convert array into a hash table
$proxy_tasks = $proxy_tasks | Sort-Object -Property Proxy,Job,VMname,Disk | Group-Object -Property Proxy -AsHashTable

# Output all of the collected information to the screen
foreach ($proxy in $proxies) {
    write-host -NoNewline -ForegroundColor green $proxy.Name "- Running:" $proxy_tasks.($proxy.Name).Count "of" $proxy.Options.MaxTasksCount "Tasks"
    if ($proxy_tasks.($proxy.Name).Count -eq 0) {write-host;write-host}
    $proxy_tasks.($proxy.Name) | Format-Table Job, VMname, Disk, Progress
}
