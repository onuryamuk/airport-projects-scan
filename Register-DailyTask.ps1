<#
.SYNOPSIS  Registers (or removes) a Windows Task Scheduler job that runs Refresh-Feeds.ps1 daily.
.NOTES     This creates persistent configuration on the workstation. Run it deliberately; it is not run by the build.
           The task only runs while the machine is on and logged in / has network access. It is a scheduled scan,
           not continuous monitoring, and it does not change project records - it produces candidates for review.
.EXAMPLE   powershell -ExecutionPolicy Bypass -File refresh\Register-DailyTask.ps1 -Time 07:30
.EXAMPLE   powershell -ExecutionPolicy Bypass -File refresh\Register-DailyTask.ps1 -Remove
#>
param([string]$Time = '07:30', [switch]$Remove, [string]$TaskName = 'AviationMarketIntel-DailyRefresh')
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if ($Remove) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; Write-Host "Removed $TaskName"; return }
$script = Join-Path $root 'refresh\Refresh-Feeds.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'Daily aviation news feed scan for the airport projects tracker (writes candidates for analyst review).' | Out-Null
[Environment]::SetEnvironmentVariable('AMI_SCHEDULED','1','User')
Write-Host "Registered $TaskName to run daily at $Time. Remove with -Remove."
