Write-Host 'ReadKey-Demo'
Write-Host

Write-Host 'Wait for KeyDown event first, then for KeyUp-Event'
Write-Host 'Only in KeyUp event are modification keys visible'

$Host.UI.RawUI.ReadKey('IncludeKeyDown, NoEcho')

Read-Host 'After pressing Enter there will a pause of two seconds before waing for the KeyUp event'
Start-Sleep -Seconds 2

$Host.UI.RawUI.ReadKey('IncludeKeyUp')

if ($Host.UI.RawUI.KeyAvailable) { 'Key in key buffer found' }
else { 'No key in key buffer found' }
