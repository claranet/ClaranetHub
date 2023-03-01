Param (
  [Parameter(Mandatory=$true)]
  [string]$Gateway,
  [switch]$NoLog=$False
)

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Import-Module Veeam.Backup.PowerShell

Function log($message) {
  if($NoLog) { return }
  $ts = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
  Write-Host "$($ts) - $($message)"
}

# region CLASSES
class PrometheusMetric {
	[string]$Prefix
	[string]$Name
	[string]$Description
	[string]$sType
	[string[]]$Labels
	[PrometheusMetricValue[]] $Values
	[string[]]$HashMap = @()
	
	PrometheusMetric([string]$Name, [string]$Description, [string]$Type, [string[]]$Labels) {
		$this.Prefix = "veeam"
		$this.Name = $Name
		$this.Description = $Description
		$this.sType = $Type
		$this.Labels = $Labels
		$this.Values = @()
	}
	
	[void]AddValue([PrometheusMetricValue] $Value) {
		$Value.Register($this)
		$Hash = $Value.Hash()
		if($Hash -in $this.HashMap) {
			Write-Error "Value is already in list - $($Value.ToString())"
		}
		$this.HashMap += $Hash
		$this.Values += $Value
	}
	
	[string]GetName() {
		return "$($this.Prefix)_$($this.Name)"
	}
	
	[string]FlushHelp() {
		$body =@()
		$body += "# TYPE $($this.GetName()) $($this.sType)"
		$body += "# HELP $($this.GetName()) $($this.Description)"
		return $body -join "`n"
	}
	
	[string]FlushValues() {
		$body = @()
		ForEach($v in $this.Values) {
			$body += $v.ToString()
		}
		return $body -join "`n"
	}
}

class PrometheusMetricValue {
	[string]$Value
	[string[]]$Labels
	[PrometheusMetric] $Metric
	
	PrometheusMetricValue($Value, [string[]]$Labels) {
		$this.Value = $Value
		$this.Labels = $Labels
	}
	
	[void]Register([PrometheusMetric] $Metric) {
		$this.Metric = $Metric
	}
	
	[string]Hash() {
		$md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
		$utf8 = New-Object -TypeName System.Text.UTF8Encoding
		$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($this.GetIdentifier())))
		return $hash
	}
	
	[string]GetIdentifier() {
		$_Labels = @()
		For($i=0;$i -lt $this.Metric.Labels.Length;$i++) {
			$_Label = $this.Labels[$i]
			$_Label = $_Label.Replace("`"", "'")
			
			$_Labels += "$($this.Metric.Labels[$i])=`"$($_Label)`""
		}
		$_Labels = $_Labels -join ", "
		return "$($this.Metric.GetName()){$($_Labels)}"
	}
	
	[string]ToString() {
		return "$($this.GetIdentifier()) $($this.Value)"
	}
}

class PrometheusCollector {
	[string]$Prefix
	[PrometheusMetric[]]$Metrics
	
	PrometheusCollector() {
		$this.Prefix = "veeam"
		$this.Metrics = @()
	}
	PrometheusCollector($Prefix) {
		$this.Prefix = $Prefix
		$this.Metrics = @()
	}
	
	[void]AddMetric([PrometheusMetric]$Metric) {
		$this.Metrics += $Metric
	}
	[void]NewMetric([string]$Name, [string]$Description, [string]$Type, [string[]]$Labels) {
		$this.AddMetric([PrometheusMetric]::new($Name, $Description, $Type, $Labels))
	}
	
	[void]AddMetricValue([string]$Metric, $Value, $Labels) {
		$_Metric = $this.Metrics | ?{ $_.Name -eq $Metric}
		$_Metric.AddValue( [PrometheusMetricValue]::new($Value, $Labels) )
	}
	
	[string]Flush() {
		$body = @()
		ForEach($m in $this.Metrics) {
			$m.Prefix = $this.Prefix
			$body += $m.FlushHelp()
			$body += $m.FlushValues()
		}
		$body += ""
		return $body -join "`n"
	}
}
# endregion CLASSES


$c = [PrometheusCollector]::new("veeam")

$c.NewMetric("job_scheduler_state", "Is job scheduler enabled (1/0)", "gauge", @("veeam_job"))
$c.NewMetric("job_end_time_seconds", "Unix Timestamp in Seconds when job has ended", "gauge", @("veeam_job"))
$c.NewMetric("job_start_time_seconds", "Unix Timestamp in Seconds when job has started", "gauge", @("veeam_job"))
$c.NewMetric("job_status", "job backup status", "gauge", @("veeam_job", "state", "status"))
		

# region Collect Session States
log "Fetch jobs and it last backup sessions"
$backupJobs = Get-VBRJob
$lastSessions = $backupJobs | %{ $_.FindLastSession() } | ?{ $_.OrigJobName }

log "Build job session details"
ForEach($session in $lastSessions) {
	$uxStartTime = ([DateTimeOffset]$session.Progress.StartTimeUtc).ToUnixTimeSeconds()
	$uxStopTime = ([DateTimeOffset]$session.Progress.StopTimeUtc).ToUnixTimeSeconds()
	$status = 0
	$AccpetedStates = @("Success")
	if($session.Result -in $AccpetedStates) { $status = 1 }
	
	log "Job Scheduler state $($session.IsScheduleEnabled)"
	$c.AddMetricValue("job_scheduler_state", [int]$session.GetJob().IsScheduleEnabled, @($session.OrigJobName))
	$c.AddMetricValue("job_end_time_seconds", $uxStopTime, @($session.OrigJobName))
	$c.AddMetricValue("job_start_time_seconds", $uxStartTime, @($session.OrigJobName))
	$c.AddMetricValue("job_status", $status, @($session.OrigJobName, $session.State, $session.Result))
}
# endregion Collect Session States

# region Collect Job VM Data
$VMLabels = @("veeam_job", "vm_name", "object_id", "status")
$c.NewMetric("job_vm_status", "", "gauge", $VMLabels) 
$c.NewMetric("job_vm_start_time_seconds", "Unix Timestamp of last run", "gauge", $VMLabels)
$c.NewMetric("job_vm_stop_time_seconds", "Unix Timestamp of last run ended", "gauge", $VMLabels)
$c.NewMetric("job_vm_total_size_bytes", "VM size in Bytes", "gauge", $VMLabels)
$c.NewMetric("job_vm_read_size_bytes", "Bytes read from Strage", "gauge", $VMLabels)
$c.NewMetric("job_vm_transfered_size_bytes", "Bytes send to Repository", "gauge", $VMLabels)

ForEach($job in $lastSessions) {
  log "Load task session for job $($job.Name)"
	$taskSessions = $job | Get-VBRTaskSession -ErrorAction SilentlyContinue | WHERE { $_.Name -notlike "VEEAM-DUMMY-*" }
	
	$_CACHE = @{}
	function get-parent($obj) {
		$ParentId = $obj.Info.ParentTaskSessionId
		if(-not $_CACHE[$ParentId]) {
			$_CACHE[$ParentId] = $obj.FindParent()
		}
		return $_CACHE[$ParentId]
	}
	
  log "Build VM session details"
	ForEach($taskSession in $taskSessions) {
		$objType = "vm"
		if($taskSession.ObjectPlatform.Platform -eq "EVcd") { continue }
		
		#$backup = ( $_group.Group | Sort-Object -Descending StartTime ) | Select -First 1
		$vmName = $taskSession.Name
		$vmName = $vmName.Replace("\", "\\")
		
		$jobName = $taskSession.JobName
		$vApp =  (get-parent($taskSession)).Name
		
		$uxStartTime = ([DateTimeOffset]$taskSession.Progress.StartTimeUtc).ToUnixTimeSeconds()
		$uxStopTime = ([DateTimeOffset]$taskSession.Progress.StopTimeUtc).ToUnixTimeSeconds()
		
		$readSize = $taskSession.Progress.ReadSize
		$totalSize = $taskSession.Progress.TotalSize
		$transferedSize = $taskSession.Progress.TransferedSize

		$status = 0
		$AccpetedStates = @("Success", "Pending", "InProgress")
		if($taskSession.Status -in $AccpetedStates) { $status = 1 }

		$_Labels = @($jobName, $vmName, $taskSession.ObjectId, $status)
		$c.AddMetricValue("job_vm_status", $status, $_Labels)
		$c.AddMetricValue("job_vm_start_time_seconds", $uxStartTime, $_Labels)
		$c.AddMetricValue("job_vm_stop_time_seconds", $uxStopTime, $_Labels)
		$c.AddMetricValue("job_vm_total_size_bytes", $totalSize, $_Labels)
		$c.AddMetricValue("job_vm_read_size_bytes", $readSize, $_Labels)
		$c.AddMetricValue("job_vm_transfered_size_bytes", $transferedSize, $_Labels)
	}
}
# endregion Collect Job VM Data

# region Backup Storage usage
log "Load Backups and add VM sizes"
$c.NewMetric("backup_size_bytes", "Size in bytes the VM used on storage", "gauge", @("job_name", "vm_name"))
$backups = Get-VBRBackup | ?{ $_.TypeToString -notlike "Hyper-V*"} | Group-Object Name
ForEach($group in $backups) {

	$_storages = $group.Group | %{$_.GetAllChildrenStorages()}
	$_objects = $group.Group | %{$_.GetObjects()} | Group-Object Name
	
	ForEach($_object in $_objects) {
		$_size = ($_storages | ?{ $_.ObjectId -in $_object.Group.Id }).Info.Stats.BackupSize | Measure-Object -Sum
		$c.AddMetricValue("backup_size_bytes", $_size.Sum , @($group.Name, $_object.Name))
	}
}
# endregion Backup Storage usage


# region Plugin Jobs

$c.NewMetric("pluginjob_end_time_seconds", "Unix Timestamp in Seconds when job has ended", "gauge", @("veeam_job", "type"))
$c.NewMetric("pluginjob_start_time_seconds", "Unix Timestamp in Seconds when job has started", "gauge", @("veeam_job", "type"))
$c.NewMetric("pluginjob_status", "job backup status", "gauge", @("veeam_job", "type", "state", "status"))

$jobs = Get-VBRPluginJob
ForEach($job in $jobs) {
	$jobType = $job.PluginType.ToString().ToLower()
	$status = 0
	$AccpetedStates = @("Success")
	if($job.LastResult -in $AccpetedStates) { $status = 1 }
	
	$uxStartTime = ([DateTimeOffset]$job.LastRun).ToUnixTimeSeconds()
	
	$c.AddMetricValue("pluginjob_start_time_seconds", $uxStartTime, @($job.Name, $jobType))
	$c.AddMetricValue("pluginjob_status", $status, @($job.Name, $jobType, $job.LastState, $job.LastResult))
}
# endregion Plugin Jobs


$HostName = [System.Net.Dns]::GetHostByName($env:computerName).HostName
$promPushGateway = "http://$($Gateway)/metrics/job/$($c.Prefix)_status/host_name/$($HostName)"
$payLoad = $c.Flush()

$response = Invoke-WebRequest -Uri $promPushGateway -Method Post -Body $payLoad -ContentType "application/vnd.google.protobuf; proto=io.prometheus.client.MetricFamily; charset=utf-8"
if($response.StatusCode -ne "200") {
  Write-Error "Something went wrong"
  Write-Error $response.Content
}
