Write-Host 'Console demo for PS2EXE' -ForegroundColor Yellow
Write-Host


switch ([System.IntPtr]::Size) {
    4 { Write-Host 'This is a 32-bit environment' -ForegroundColor Yellow }
    8 { Write-Host 'This is a 64-bit environment' -ForegroundColor Yellow }
}

Write-Host


switch ($PSVersionTable.PSVersion.Major) {
    5 { Write-Host 'This is PowerShell 5.x' -ForegroundColor Yellow }
    4 { Write-Host 'This is PowerShell 4.0' -ForegroundColor Cyan }
    3 { Write-Host 'This is PowerShell 3.0' -ForegroundColor Red }
    2 { Write-Host 'This is PowerShell 2.0' -ForegroundColor DarkCyan }

    default { Write-Host 'This is a unknown PowerShell version' -ForegroundColor Blue }
}

Write-Host


$apartment = [System.Threading.Thread]::CurrentThread.GetApartmentState()

Write-Host ('Thread Appartment State is {0}' -f $apartment)
Write-Host


# Keep following windows in foreground with -NoConsole

$Host.UI.RawUI.FlushInputBuffer()

$credential = Get-Credential -Credential $env:USERNAME

# $credential = $Host.UI.PromptForCredential(
#     'Authentication required',
#     'Please type user and password',
#     $env:USERNAME, $env:COMPUTERNAME
# )

$Host.UI.RawUI.FlushInputBuffer()

Write-Host


if ($credential) {
    Write-Host ('Your authentication data: {0}' -f $credential) -ForegroundColor Magenta
    Write-Host

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    Write-Host ('Your password: {0}' -f $plain)
    Write-Host
}
else {
    Write-Host 'Input aborted'
    Write-Host
}


$value = Read-Host -Prompt 'Type in a string'

Write-Host ('Your input was: {0}' -f $value)
Write-Host


# Read-Host -Prompt 'Press enter to exit' | Out-Null
Pause
