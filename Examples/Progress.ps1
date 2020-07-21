# Demo program for Write-Progress

1..10 | ForEach-Object {
	$activity  = 'Activity {0}'  -f $PSItem
	$status    = 'State {0}'     -f $PSItem
	$operation = 'Operation {0}' -f $PSItem
	$percent   = 10 * $PSItem
	$remaining = 10 - $PSItem

	Write-Progress -Activity $activity -Status $status -Id 1 -CurrentOperation $operation -PercentComplete $percent -SecondsRemaining $remaining
	Start-Sleep -Seconds 1
}

Start-Sleep -Seconds 3

Write-Progress -Activity 'Activity' -Status 'State' -Id 1 -Completed
Write-Host 'Completed'

Start-Sleep -Seconds 1

Write-Progress -Activity 'New progress' -Status 'New state' -PercentComplete 33 -SecondsRemaining 734

Start-Sleep -Seconds 3

Write-Output 'Exiting program'
