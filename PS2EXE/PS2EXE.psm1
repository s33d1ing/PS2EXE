$PS2EXE = Get-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath 'PS2EXE.ps1')

try {
    $command = Get-Command -Name $PS2EXE.FullName -CommandType 'ExternalScript'
    $metadata = [System.Management.Automation.CommandMetaData]::new($command)
    $proxy = [System.Management.Automation.ProxyCommand]::Create($metadata)

    Set-Item -Path ('Function:' + $PS2EXE.BaseName) -Value $proxy -Force
}
catch {
    Write-Error ('Failed to import script "{0}": {1}' -f $PS2EXE.BaseName, $PSItem.Exception.Message)
}

Set-Alias -Name 'Invoke-PS2EXE' -Value 'PS2EXE' -Scope Global
