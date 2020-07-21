Get-ChildItem -Path "$PSScriptRoot\Examples\*.ps1" | ForEach-Object {
    . "$PSScriptRoot\PS2EXE\ps2exe.ps1" -InputFile "$($PSItem.FullName)" `
        -OutputFile ("$PSScriptRoot\Output\$($PSItem.Name)" -replace ".ps1", ".exe") `
        -IconFile "$PSScriptRoot\Resources\PowerShell.ico" `
        -FileDescription "Console Application" -FileVersion "1.0.1.1" `
        -ProductName "$($PSItem.Name)" -ProductVersion "1.0.0-rc.1+CLI" `
        -LegalCopyright "$(Get-Date)" -Verbose -Debug

    . "$PSScriptRoot\PS2EXE\ps2exe.ps1" -InputFile "$($PSItem.FullName)" `
        -OutputFile ("$PSScriptRoot\Output\$($PSItem.Name)" -replace ".ps1", "-GUI.exe") `
        -IconFile "$PSScriptRoot\Resources\PowerShell.ico" `
        -FileDescription "Windows Application" -FileVersion "1.0.1.1" `
        -ProductName "$($PSItem.Name)" -ProductVersion "1.0.0-rc.1+GUI" `
        -LegalCopyright "$(Get-Date)" -NoConsole -Verbose -Debug
}

Remove-Item -Path "$PSScriptRoot\Output\Progress.exe*" -Force
Remove-Item -Path "$PSScriptRoot\Output\ScreenBuffer-GUI.exe*" -Force
