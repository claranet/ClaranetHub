# Veeam Maintenance Mode

VEEAM has no option to set a maintenance mode. This Script will dump each job
state (active or inactive) to a JSON File. Then all jobs are triggered to stop
and set to disabled. After a while there should be no more no running jobs.

This is perfect for debugging or updates.

Leaving Maintenance Mode, the script reads the JSON, set jobs to enabled and
and triggered a retry on failed job.

## The Scrtips

 * Enter-Maintenance.ps1 - Enters the Maintenance mode
 * Leave-Maintenance.ps1 - Leave the Maintenance mode

Just place this scritp to your Desktop, right klick  and "run with powershell"
