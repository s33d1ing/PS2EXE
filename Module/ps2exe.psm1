<#
    .SYNOPSIS
        PS2EXE is a module to compile PowerShell scripts to executables.

    .NOTES
        Version: 1.1.0
        Date: 2020-04-02
        Author: Markus Scholtes, Garrett Dees
#>

# Load modules manually for security reasons
. "$PSScriptRoot/ps2exe.ps1"

# Define aliases
Set-Alias -Name 'ps2exe' -Value 'Invoke-PS2EXE' -Scope Global
Set-Alias -Name 'ps2exe.ps1' -Value 'Invoke-PS2EXE' -Scope Global
Set-Alias -Name 'Win-PS2EXE' -Value "$PSScriptRoot\Win-PS2EXE.exe" -Scope Global
Set-Alias -Name 'Win-PS2EXE.exe' -Value "$PSScriptRoot\Win-PS2EXE.exe" -Scope Global

# Export functions
# Export-ModuleMember -Function @('Invoke-PS2EXE')

# Export aliases
# Export-ModuleMember -Alias @('ps2exe', 'ps2exe.ps1', 'Win-PS2EXE', 'Win-PS2EXE.exe')
