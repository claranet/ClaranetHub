# VEEAM Exporter for Prometheus metrics

This Powershell script collects metrics from VEEAM and send it to a given
Prometheus Push-Gateway. The data can be collected there and evaluate.

Why no a API based Exporter?

I tried to write an exporter using the VEEAM rest API but it seems that are a lot
of informations about the backups are missing there. Specially I missed details 
about the storage usage and 

## Job Compabibility (Tested)

In shord words: All jobs returend by `Get-VBRJob`

* VMware Backup
* HyperV
* FileLevel Backups
* Backup Copy
* Oracle RMAN job

## Quick Installation

The Script below downloads the Exporter Script to current directory
and installed a Task Scheduler to run it every hour.

```
$Gateway = "1.2.3.5:9091" # Change ME !!

Invoke-WebRequest -OutFile Export-Metrics.ps1 -Uri "https://raw.githubusercontent.com/claranet/VeeamHub/master/Prometheus Exporter/Export-Metrics.ps1"
$__action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -File $((Get-Location).Path)\Export-Metrics.ps1 -Gateway $($Gateway)"
$__trigger = New-ScheduledTaskTrigger -Daily -At 00:00
$__task = Register-ScheduledTask -TaskName "VEEAM Exporter" -User SYSTEM -Trigger $__trigger -Action $__action
$__task.Triggers.Repetition.Duration = "P1D"
$__task.Triggers.Repetition.Interval = "PT1H"
$__task | Set-ScheduledTask
```

## Troubleshooting

If connection cannot be established to the pushgateway check the firewalls
and test the connection using 
```
Test-NetConnection <IP> -Port 9091
```

## Read More

For Prometheus and it setup visit https://prometheus.io
