# Example script to retrieve path to script

# When compiled with PS2EXE the variable MyCommand contains no path anymore

# PowerShell script
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    $script = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
}

# PS2EXE compiled script
else {
    $script = Split-Path -Path ([Environment]::GetCommandLineArgs()[0]) -Parent
}

Write-Output ('Directory of executable file: {0}' -f $script)
