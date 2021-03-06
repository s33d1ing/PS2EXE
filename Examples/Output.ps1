$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'

Write-Output  'Write-Output'
Write-Debug   'Write-Debug'
Write-Verbose 'Write-Verbose'
Write-Warning 'Write-Warning'
Write-Error   'Write-Error'

# Keep following Windows in foreground with -NoConsole:
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()

Read-Host -Prompt 'Read-Host: Press key to exit'

Write-Host 'Write-Host: Done'
