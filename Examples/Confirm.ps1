Write-Host 'Creating file ".\test.txt"'
Get-ChildItem | Out-File -FilePath .\test.txt

Write-Host 'Removing file ".\test.txt" depending on confirmation.'
Remove-Item -Path .\test.txt -Confirm

if (Test-Path '.\Test.txt') { 'File ".\test.txt" is still there.' }
else { 'File ".\test.txt" was deleted.' }
