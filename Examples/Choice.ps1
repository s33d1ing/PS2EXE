$choices = [System.Management.Automation.Host.ChoiceDescription[]](
    (New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes', 'Choose me!'),
    (New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&No', 'Pick me!'),
    (New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Cancel', '')
)

$answer = $Host.UI.PromptForChoice('Title', 'Question', $choices, 2)

Write-Output $answer


$fields = New-Object -TypeName System.Collections.ObjectModel.Collection[System.Management.Automation.Host.FieldDescription]

$f = New-Object -TypeName System.Management.Automation.Host.FieldDescription -ArgumentList 'String Field'

$f.HelpMessage  = 'This is the help for the first field'
$f.DefaultValue = 'Field1'
$f.Label = '&Any Text'

$fields.Add($f)


$f = New-Object -TypeName System.Management.Automation.Host.FieldDescription -ArgumentList 'Secure String'

$f.SetparameterType([System.Security.SecureString])
# $f.SetparameterType([String])
$f.HelpMessage  = 'You will get a password input with **** instead of characters'
$f.DefaultValue = 'Password'
$f.Label = '&Password'

$fields.Add($f)


$f = New-Object -TypeName System.Management.Automation.Host.FieldDescription -ArgumentList 'Numeric Value'

$f.SetparameterType([int])
$f.DefaultValue = '42'
$f.HelpMessage  = 'You need to type a number, or it will re-prompt'
$f.Label = '&Number'

$fields.Add($f)


$results = $Host.UI.Prompt('Next title', 'Next question', $fields)

Write-Output $results


$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($results['Secure String'])
$plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

Write-Output ('Given password: {0}' -f $plain)
