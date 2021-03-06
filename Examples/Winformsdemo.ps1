[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')

switch ([System.IntPtr]::Size) {
    4 { [void][System.Windows.Forms.MessageBox]::Show('This is a 32 bit environment', 'WinForms demo for PS2EXE', 0) }
    8 { [void][System.Windows.Forms.MessageBox]::Show('This is a 64 bit environment', 'WinForms demo for PS2EXE', 0) }
}

switch ($PSVersionTable.PSVersion.Major) {
    5 { $version = 'This is PowerShell 5.x' }
    4 { $version = 'This is PowerShell 4.0' }
    3 { $version = 'This is PowerShell 3.0' }
    2 { $version = 'This is PowerShell 2.0' }

    default { $version = 'This is a unknown PowerShell version' }
}

[void][System.Windows.Forms.MessageBox]::Show($version, 'WinForms demo for PS2EXE', 0)


$apartment = [System.Threading.Thread]::CurrentThread.GetApartmentState()

[void][System.Windows.Forms.MessageBox]::Show(('Thread Appartment State is {0}' -f $apartment), 'WinForms demo for PS2EXE', 0)


# Keep following windows in foreground with -NoConsole:

$Host.UI.RawUI.FlushInputBuffer()

# $credential = Get-Credential -Credential $env:USERNAME
$credential = $Host.UI.PromptForCredential('Authentication required', 'Please type user and password', $env:USERNAME, $env:COMPUTERNAME)

$Host.UI.RawUI.FlushInputBuffer()


if ($credential) {
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    [void][System.Windows.Forms.MessageBox]::Show(($credential.UserName + [System.Environment]::NewLine + $plain), 'Your authentication data:', 0)
}
else {
    Write-Output 'Input aborted'
}
