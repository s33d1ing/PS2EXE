param ([string]$Text = 'Default Value', [int]$Number = 0, [switch]$Select, [array]$StringArray)

Write-Host ('Text: {0}' -f $Text)
Write-Host ('Number: {0}' -f $Number)
Write-Host ('Select: {0}' -f $Select)

if ($StringArray) { Write-Host ('Array: {0}' -f $StringArray) }
