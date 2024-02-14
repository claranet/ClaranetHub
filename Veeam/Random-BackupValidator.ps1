<#
.SYNOPSIS
Validate random backup objects and create HTML Report

.DESCRIPTION
Validating backup chain for a while job can take a long time. This script select
random backup job and random objects to validate and create report.

Works with backups from:
* VMware
* AHV
* HyperV

Read more
* https://helpcenter.veeam.com/docs/backup/vsphere/backup_validator_validate.html?ver=120

.NOTES
  Name: Random-BackupValidator.ps1
  Author: Martin Weber (martin.weber@de.clara.net)
  Create: 24.01.2024
  Modified: -

.PARAMETER Count
Maximum number of objects to validate

.PARAMETER Lock
Create lock-file and prevent running multiple times

.EXAMPLE
./Random-BackupValidator.ps1 -Count 5

#>

param(
  [int]$Count = 1,
  [switch] $Lock = $False
)

BEGIN {
  Add-PSSnapIn VeeamPSSNapin

  #Set the email server, sender and recipient
  $MailConfig = Get-VBRMailNotificationConfiguration
  $SMTPServer = $MailConfig.SmtpServer
  $SenderAddr = $MailConfig.Sender
  $DestinationAddr = $MailConfig.Recipient

  # Write Lockfile to prevent multiplte running validators if needed
  $LOCKFILE_PATH = "$($env:TEMP)/veeam.backup.validator.lock"
  if( $Lock -and [System.IO.File]::Exists($LOCKFILE_PATH) ) {
    Write-Host "A Backup validator job seems already running - exit"
    Break
  }
  echo $NULL > $LOCKFILE_PATH

  # Set Variable for maximum object to fetch from backup job
  $MAX_OBJECTS = $Count

  $date = (Get-Date).AddDays(-1).ToString('dd-MM-yyyy')

  # Get a random backup from config
  $job = Get-VBRBackup | ?{ -not $_.IsExported } | Get-Random
  $MailSubject = "Veeam Validation Report for $job.Name"
  if( -not $job.IsMetaExist ) {
    $job = $job.FindChildBackups() | Get-Random -Count $MAX_OBJECTS
  }
  $reportStack = @()
}

PROCESS {
  ForEach($_job in $job) {
    $jobname = $_job.Name
    
    # Select random objects from backup
    $object = $_job.GetObjects($True).Name | Get-Random -Count $MAX_OBJECTS

    # The html output file
    $VeeamOutputFile = "$($env:TEMP)/VMe-$jobname-$date.html"

    #Runs the exe file with the necessary parameters 
    $args = @( "/backup:`"$jobname`"", "/format:html", "/report:`"$VeeamOutputFile`"" )
    $args += ($object | %{ "/vmname:`"$($_)`"" })
    Start-Process -ArgumentList $args -FilePath "C:\Program Files\Veeam\Backup and Replication\Backup\veeam.backup.validator.exe" -wait

    $reportStack += $VeeamOutputFile
  }
}

END {
  #Sends the output files to a recipient
  $body = (Get-Content $reportStack -Raw) -Join "`n"
  
  Send-MailMessage -From "<$SenderAddr>" `
                   -To "<$DestinationAddr>" `
                   -Subject $MailSubject `
                   -Body $body -BodyAsHtml `
                   -dno onSuccess, onFailure `
                   -SmtpServer $SMTPServer `
                   -Encoding "utf8"

  Remove-Item $LOCKFILE_PATH
}
