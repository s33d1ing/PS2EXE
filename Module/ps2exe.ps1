#Requires -Version 2.0

<#
    .SYNOPSIS
        Converts PowerShell scripts to standalone executables.

    .DESCRIPTION
        Converts PowerShell scripts to standalone executables. GUI output and input is activated with one switch,
        real windows executables are generated. You may use the graphical front end Win-PS2EXE for convenience.

        Please see Remarks on project page for topics "GUI mode output formatting", "Config files",
        "Password security", "Script variables" and "Window in background in -noConsole mode".

        The generated executables has the following reserved parameters:

            -Debug              Forces the executable to be debugged. It calls "System.Diagnostics.Debugger.Break()".

            -Extract:<Path>     Extracts the powerShell script inside the executable and saves it as the specified Path.
                                The script will not be executed.

            -Wait               At the end of the script execution it writes "Hit any key to exit..." and waits for a key to be pressed.

            -End                All following options will be passed to the script inside the executable.
                                All preceding options are used by the executable itself and will not be passed to the script.

    .PARAMETER InputFile
        PowerShell script that you want to convert to executable

    .PARAMETER OutputFile
        Destination executable file name, defaults to InputFile with extension ".exe"

    .PARAMETER IconFile
        Icon file name for the compiled executable

    .PARAMETER Title
        Title information (displayed in details tab of Windows Explorer's properties dialog)

    .PARAMETER Description
        Description information (not displayed, but embedded in executable)

    .PARAMETER Company
        Company information (not displayed, but embedded in executable)

    .PARAMETER Product
        Product information (displayed in details tab of Windows Explorer's properties dialog)

    .PARAMETER Copyright
        Copyright information (displayed in details tab of Windows Explorer's properties dialog)

    .PARAMETER Trademark
        Trademark information (displayed in details tab of Windows Explorer's properties dialog)

    .PARAMETER Version
        Version information (displayed in details tab of Windows Explorer's properties dialog)

    .PARAMETER LCID
        Location ID for the compiled executable. Current user culture if not specified.

    .PARAMETER Runtime20
        This switch forces PS2EXE to create a config file for the generated executable that contains the
        "supported .NET Framework versions" setting for .NET Framework 2.0/3.x for PowerShell 2.0

    .PARAMETER Runtime40
        This switch forces PS2EXE to create a config file for the generated executable that contains the
        "supported .NET Framework versions" setting for .NET Framework 4.x for PowerShell 3.0 or higher

    .PARAMETER x86
        Compile for 32-bit runtime only

    .PARAMETER x64
        Compile for 64-bit runtime only

    .PARAMETER STA
        Single Thread Apartment mode

    .PARAMETER MTA
        Multi Thread Apartment mode

    .PARAMETER NoConsole
        The resulting executable will be a Windows Forms app without a console window.

        You might want to pipe your output to Out-String to prevent a message box for every line of output
        (Example: dir C:\ | Out-String)

    .PARAMETER CredentialGUI
        Use GUI for prompting credentials in console mode instead of console input

    .PARAMETER ConfigFile
        Write a config file (<OutputFile>.exe.config)

    .PARAMETER NoOutput
        The resulting executable will generate no standard output (includes verbose and information channel)

    .PARAMETER NoError
        The resulting executable will generate no error output (includes warning and debug channel)

    .PARAMETER RequireAdmin
        If UAC is enabled, compiled executable will run only in elevated context (UAC dialog appears if required)

    .PARAMETER SupportOS
        Use functions of newest Windows versions (execute [System.Environment]::OSVersion to see the difference)

    .PARAMETER Virtualize
        Application virtualization is activated (forcing x86 runtime)

    .PARAMETER LongPaths
        Enable long paths (>260 characters) if enabled on OS (works only with Windows 10)

    .EXAMPLE
        ps2exe.ps1 C:\Data\MyScript.ps1
        Compiles "C:\Data\MyScript.ps1" to "C:\Data\MyScript.exe" as a console executable

    .EXAMPLE
        ps2exe.ps1 -InputFile C:\Data\MyScript.ps1 -OutputFile C:\Data\MyScriptGUI.exe -IconFile C:\Data\Icon.ico -NoConsole -Title "MyScript" -Version 0.1.0
        Compiles "C:\Data\MyScript.ps1" to "C:\Data\MyScriptGUI.exe" as a graphical executable, with icon and version metadata

    .NOTES
        Version: 0.5.0.19
        Date: 2020-02-15
        Author: Ingo Karstein, Markus Scholtes, Garrett Dees

        PowerShell 2.0 incompatibilities:
            -in and -notin operators
            DontShow parameter attribute
            .Net type's new() method
            $PSItem pipeline variable
            -ErrorAction Ignore

    .LINK
        https://gallery.technet.microsoft.com/PS2EXE-GUI-Convert-e7cb69d5
#>


[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$InputFile = [string]::Empty,
    [Parameter(Position = 1)]
    [string]$OutputFile = [string]::Empty,
    [Parameter(Position = 2)]
    [string]$IconFile = [string]::Empty,

    [string]$Title,         # File Description
    [string]$Description,   # Comments (Not shown in details)
    [string]$Company,       # Company (Not shown in details)
    [string]$Product,       # Product Name
    [string]$Copyright,     # Copyright
    [string]$Trademark,     # Legal Trademarks
    [string]$Version,       # File & Product Version(s)

    [nullable[int]]$LCID,
    [switch]$Runtime20,
    [switch]$Runtime40,
    [switch]$x86,
    [switch]$x64,
    [switch]$STA,
    [switch]$MTA,

    [switch]$NoConsole,
    [switch]$CredentialGUI,
    [switch]$ConfigFile,
    [switch]$NoOutput,
    [switch]$NoError,
    [switch]$RequireAdmin,
    [switch]$SupportOS,
    [switch]$Virtualize,
    [switch]$LongPaths,

    [switch]$Nested
)


$ErrorActionPreference = 'Stop'

if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' }
if ($PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = 'Continue' }

# Populate automatic variables that are not available in PowerShell 2.0
if ($null -eq $PSCommandPath) { $PSCommandPath = $MyInvocation.MyCommand.Definition }
if ($null -eq $PSScriptRoot) { $PSScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition }


function Get-FullName ([string]$Path) {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}


<################################################################################>
<##                                                                            ##>
<##      PS2EXE-GUI v0.5.0.19                                                  ##>
<##      Written by: Ingo Karstein (http://blog.karstein-consulting.com)       ##>
<##      Reworked and GUI support by Markus Scholtes                           ##>
<##      Refactor by Garrett Dees                                              ##>
<##                                                                            ##>
<##      This script is released under Microsoft Public Licence                ##>
<##          that can be downloaded here:                                      ##>
<##          http://www.microsoft.com/opensource/licenses.mspx#Ms-PL           ##>
<##                                                                            ##>
<################################################################################>


if (-not $Nested) {
    Write-Output 'PS2EXE-GUI v0.5.0.19 by Ingo Karstein'
    Write-Output 'Reworked and GUI support by Markus Scholtes'
    Write-Output 'Refactor by Garrett Dees'
}


if ([string]::IsNullOrEmpty($InputFile)) {
    $help = New-Object -TypeName System.Text.StringBuilder

    [void]$help.AppendLine('Usage:')
    [void]$help.AppendLine()
    [void]$help.AppendLine('ps2exe.ps1 [-InputFile] "<FileName>" [[-OutputFile] "<FileName>"] [[-IconFile] "<FileName>"]')
    [void]$help.AppendLine()
    [void]$help.AppendLine('    [-Title "<Title>"] [-Description "<Description>"] [-Company "<Company>"] [-Product "<Product>"]')
    [void]$help.AppendLine('    [-Copyright "<Copyright>"] [-Trademark "<Trademark>"] [-Version "<Version>"]')
    [void]$help.AppendLine()
    [void]$help.AppendLine('    [-LCID <ID>] [-Runtime20|-Runtime40] [-x86|-x64] [-STA|-MTA]')
    [void]$help.AppendLine()
    [void]$help.AppendLine('    [-NoConsole] [-CredentialGUI] [-ConfigFile] [-NoOutput] [-NoError] ')
    [void]$help.AppendLine('    [-RequireAdmin] [-SupportOS] [-Virtualize] [-LongPaths]')
    [void]$help.AppendLine()
    [void]$help.AppendLine()
    [void]$help.AppendLine('    InputFile = PowerShell script that you want to convert to executable')
    [void]$help.AppendLine('   OutputFile = Destination executable file name, defaults to InputFile with extension ".exe"')
    [void]$help.AppendLine('     IconFile = Icon file name for the compiled executable')
    [void]$help.AppendLine()
    [void]$help.AppendLine('        Title = Title information (displayed in details tab of Windows Explorer''s properties dialog)')
    [void]$help.AppendLine('  Description = Description information (not displayed, but embedded in executable)')
    [void]$help.AppendLine('      Company = Company information (not displayed, but embedded in executable)')
    [void]$help.AppendLine('      Product = Product information (displayed in details tab of Windows Explorer''s properties dialog)')
    [void]$help.AppendLine('    Copyright = Copyright information (displayed in details tab of Windows Explorer''s properties dialog)')
    [void]$help.AppendLine('    Trademark = Trademark information (displayed in details tab of Windows Explorer''s properties dialog)')
    [void]$help.AppendLine('      Version = Version information (displayed in details tab of Windows Explorer''s properties dialog)')
    [void]$help.AppendLine()
    [void]$help.AppendLine('         LCID = Location ID for the compiled executable. Current user culture if not specified')
    [void]$help.AppendLine('    Runtime20 = This switch forces PS2EXE to create a config file for the generated executable that contains the')
    [void]$help.AppendLine('                "supported .NET Framework versions" setting for .NET Framework 2.0/3.x for PowerShell 2.0')
    [void]$help.AppendLine('    Runtime40 = This switch forces PS2EXE to create a config file for the generated executable that contains the')
    [void]$help.AppendLine('                "supported .NET Framework versions" setting for .NET Framework 4.x for PowerShell 3.0 or higher')
    [void]$help.AppendLine('   x86 or x64 = Compile for 32-bit or 64-bit runtime only')
    [void]$help.AppendLine('   STA or MTA = "Single Thread Apartment" or "Multi Thread Apartment" mode')
    [void]$help.AppendLine()
    [void]$help.AppendLine('    NoConsole = The resulting executable will be a Windows Forms app without a console window')
    [void]$help.AppendLine('CredentialGUI = Use GUI for prompting credentials in console mode instead of console input')
    [void]$help.AppendLine('   ConfigFile = Write a config file (<OutputFile>.exe.config)')
    [void]$help.AppendLine('     NoOutput = The resulting executable will generate no standard output (includes verbose and information channel)')
    [void]$help.AppendLine('      NoError = The resulting executable will generate no error output (includes warning and debug channel)')
    [void]$help.AppendLine(' RequireAdmin = If UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required)')
    [void]$help.AppendLine('    SupportOS = Use functions of newest Windows versions (execute [System.Environment]::OSVersion to see the difference)')
    [void]$help.AppendLine('   Virtualize = Application virtualization is activated (forcing x86 runtime)')
    [void]$help.AppendLine('    LongPaths = Enable long paths (>260 characters) if enabled on OS (works only with Windows 10)')
    [void]$help.AppendLine()
    [void]$help.AppendLine()
    [void]$help.AppendLine('Input file not specified!')

    Write-Output $help.ToString()

    exit -1
}


switch ($PSVersionTable.PSVersion.Major) {
    { $_ -ge 4 } {
        Write-Verbose 'You are using PowerShell 4.0 or above.'
        $PSVersion = 4
    }

    { $_ -eq 3 } {
        Write-Verbose 'You are using PowerShell 3.0.'
        $PSVersion = 3
    }

    { $_ -eq 2 } {
        Write-Verbose 'You are using PowerShell 2.0.'
        $PSVersion = 2
    }

    default {
        Write-Error 'The PowerShell version is unknown!'
    }
}


#region Parameter Validation

$PSBoundParameters.GetEnumerator() | ForEach-Object { Write-Debug ('${0} = {1}' -f $_.Key, $_.Value) }
# $args | ForEach-Object -Begin { $i = 0 } -Process { Write-Debug ('$args[{0}] = {1}' -f $i++, $_) }


if (-not [string]::IsNullOrEmpty($InputFile)) {
    $InputFile = Get-FullName -Path $InputFile

    if (-not (Test-Path -Path $InputFile -PathType Leaf)) {
        Write-Error ('Input file "{0}" not found!' -f $InputFile)
    }
}
else {
    Write-Error 'Input file is required!'
}


if (-not [string]::IsNullOrEmpty($OutputFile)) {
    $OutputFile = Get-FullName -Path $OutputFile

    if ($InputFile -eq $OutputFile) {
        Write-Error 'Input file is identical to output file!'
    }

    if (-not (Test-Path -Path (Split-Path -Path $OutputFile -Parent) -PathType Container)) {
        Write-Error ('Output directory "{0}" not found!' -f (Split-Path -Path $OutputFile -Parent))
    }

    if (($OutputFile -notlike '*.exe') -and ($OutputFile -notlike '*.com')) {
        Write-Error 'Output file must have ".exe" or ".com" extension!'
    }

}
else {
    $OutputFile = [System.IO.Path]::Combine(
        [System.IO.Path]::GetDirectoryName($InputFile),
        [System.IO.Path]::GetFileNameWithoutExtension($InputFile) + '.exe'
    )
}


if (-not [string]::IsNullOrEmpty($IconFile)) {
    $IconFile = Get-FullName -Path $IconFile

    if (-not (Test-Path -Path $IconFile -PathType Leaf)) {
        Write-Error ('Icon file not found!' -f $IconFile)
    }
}


# Escape escape sequences in version info
$Title = $Title -replace '\\', '\\'
$Product = $Product -replace '\\', '\\'
$Copyright = $Copyright -replace '\\', '\\'
$Trademark = $Trademark -replace '\\', '\\'
$Description = $Description -replace '\\', '\\'
$Company = $Company -replace '\\', '\\'

# Check for correct version number information
if (-not [string]::IsNullOrEmpty($Version)) {
    if ($Version -notmatch '^(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?(?:\.(0|[1-9]\d*))?(?:\.(0|[1-9]\d*))?$') {
        Write-Error 'Version number must be in the form of "n", "n.n", "n.n.n", or "n.n.n.n"!'
    }
}


# Set the default runtime based on PowerShell version
if ((-not $Runtime20) -and (-not $Runtime40)) {
    if ($PSVersion -ge 3) { $Runtime40 = $true }
    else { $Runtime20 = $true }
}

# Set the default apartment model based on PowerShell version
if (($PSVersion -lt 3) -and (-not $MTA) -and (-not $STA)) { $MTA = $true }
if (($PSVersion -ge 3) -and (-not $MTA) -and (-not $STA)) { $STA = $true }


if ($RequireAdmin -and $Virtualize) {
    Write-Error '-RequireAdmin and -Virtualize cannot be combined!'
}

if ($SupportOS -and $Virtualize) {
    Write-Error '-SupportOS and -Virtualize cannot be combined!'
}

if ($LongPaths -and $Virtualize) {
    Write-Error '-LongPaths and -Virtualize cannot be combined!'
}

if ($LongPaths -and $Runtime20) {
    Write-Error '-LongPaths and -Runtime20 cannot be combined!'
}

if ($Runtime20 -and $Runtime40) {
    Write-Error '-Runtime20 and -Runtime40 cannot be combined!'
}

if ($STA -and $MTA) {
    Write-Error '-STA and -MTA cannot be combined!'
}

if (($PSVersion -lt 3) -and $Runtime40) {
    Write-Error 'You need to run ps2exe in an Powershell 3.0 or higher environment to use parameter -Runtime40'
}


if ((-not $ConfigFile) -and $RequireAdmin) {
    Write-Warning 'Forcing generation of a config file, because -RequireAdmin requires it.'
}

if ((-not $ConfigFile) -and $SupportOS) {
    Write-Warning 'Forcing generation of a config file, because -SupportOS requires it.'
}

if ((-not $ConfigFile) -and $LongPaths) {
    Write-Warning 'Forcing generation of a config file, because -LongPaths requires it.'
}

#endregion


if (($PSVersion -ge 3) -and $Runtime20) {
    Write-Output 'To create an executable for PowerShell 2.0 in PowerShell 3.0 or above, this script will relaunch in PowerShell 2.0...'

    if ($Runtime20 -and ($MyInvocation.MyCommand.CommandType -ne 'ExternalScript')) {
        Write-Warning 'The parameter -Runtime20 is not supported for compiled ps2exe.ps1 scripts.'
        Write-Warning 'Compile ps2exe.ps1 with parameter -Runtime20 and call the generated executable without -Runtime20.'

        exit 1
    }


    $arguments = New-Object -TypeName System.Text.StringBuilder

    [void]$arguments.AppendFormat('-InputFile "{0}" -OutputFile "{1}" ', $InputFile, $OutputFile)

    if (-not [string]::IsNullOrEmpty($IconFile)) { [void]$arguments.AppendFormat('-IconFile "{0}" ', $IconFile) }
    if (-not [string]::IsNullOrEmpty($Title)) { [void]$arguments.AppendFormat('-Title "{0}" ', $Title) }
    if (-not [string]::IsNullOrEmpty($Description)) { [void]$arguments.AppendFormat('-Description "{0}" ', $Description) }
    if (-not [string]::IsNullOrEmpty($Company)) { [void]$arguments.AppendFormat('-Company "{0}" ', $Company) }
    if (-not [string]::IsNullOrEmpty($Product)) { [void]$arguments.AppendFormat('-Product "{0}" ', $Product) }
    if (-not [string]::IsNullOrEmpty($Copyright)) { [void]$arguments.AppendFormat('-Copyright "{0}" ', $Copyright) }
    if (-not [string]::IsNullOrEmpty($Trademark)) { [void]$arguments.AppendFormat('-Trademark "{0}" ', $Trademark) }
    if (-not [string]::IsNullOrEmpty($Version)) { [void]$arguments.AppendFormat('-Version "{0}" ', $Version) }

    if ($null -ne $LCID) { [void]$arguments.AppendFormat('-LCID {0} ', $LCID) }

    if ($Runtime20.IsPresent) { [void]$arguments.Append('-Runtime20 ') }
    # if ($Runtime40.IsPresent) { [void]$arguments.Append('-Runtime40 ') }

    if ($x86.IsPresent) { [void]$arguments.Append('-x86 ') }
    if ($x64.IsPresent) { [void]$arguments.Append('-x64 ') }

    if ($STA.IsPresent) { [void]$arguments.Append('-STA ') }
    if ($MTA.IsPresent) { [void]$arguments.Append('-MTA ') }

    if ($NoConsole.IsPresent) { [void]$arguments.Append('-NoConsole ') }
    if ($NoOutput.IsPresent) { [void]$arguments.Append('-NoOutput ') }
    if ($NoError.IsPresent) { [void]$arguments.Append('-NoError ') }
    if ($RequireAdmin.IsPresent) { [void]$arguments.Append('-RequireAdmin ') }
    if ($Virtualize.IsPresent) { [void]$arguments.Append('-Virtualize ') }
    if ($CredentialGUI.IsPresent) { [void]$arguments.Append('-CredentialGUI ') }
    if ($SupportOS.IsPresent) { [void]$arguments.Append('-SupportOS ') }
    if ($ConfigFile.IsPresent) { [void]$arguments.Append('-ConfigFile ') }

    [void]$arguments.Append('-Nested ')

    if ($PSBoundParameters.ContainsKey('Debug')) { [void]$arguments.Append('-Debug ') }
    if ($PSBoundParameters.ContainsKey('Verbose')) { [void]$arguments.Append('-Verbose ') }


    $command = '. "{0}\powershell.exe" -Version 2.0 -Command ''& "{1}" {2}''' -f $PSHOME, $PSCommandPath, $arguments.ToString()

    Write-Debug ('Invoking: {0}' -f $command)
    Invoke-Expression -Command $command

    exit 0
}


#region Compiler Options

$options = New-Object -TypeName 'System.Collections.Generic.Dictionary[System.String, System.String]'
$assembies = New-Object -TypeName 'System.Collections.Generic.List[System.Object]'


if ($PSVersion -ge 3) {
    $options.Add('CompilerVersion', 'v4.0')
}
else {
    if (Test-Path -Path ('{0}\Microsoft.NET\Framework\v3.5\csc.exe' -f $env:windir)) {
        $options.Add('CompilerVersion', 'v3.5')
    }
    else {
        $Compiler20 = $true

        Write-Warning 'No .Net 3.5 compiler found, using .Net 2.0 compiler.'
        Write-Warning 'Some methods will not be available!'

        $options.Add('CompilerVersion', 'v2.0')
    }
}


$assembies.Add('System.dll')

$assembies.Add((([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
    $_.ManifestModule.Name -eq 'System.Management.Automation.dll'
} | Select-Object -First 1) | Select-Object -ExpandProperty Location))

if ($Runtime40) {
    $core = New-Object -TypeName System.Reflection.AssemblyName -ArgumentList (
        'System.Core, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
    )

    [System.AppDomain]::CurrentDomain.Load($core) | Out-Null

    $assembies.Add((([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
        $_.ManifestModule.Name -eq 'System.Core.dll'
    } | Select-Object -First 1) | Select-Object -ExpandProperty Location))
}

if (-not $NoConsole) {
    if ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
        $_.ManifestModule.Name -eq 'Microsoft.PowerShell.ConsoleHost.dll'
    }) {
        $assembies.Add((([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
            $_.ManifestModule.Name -eq 'Microsoft.PowerShell.ConsoleHost.dll'
        } | Select-Object -First 1) | Select-Object -ExpandProperty Location))
    }
}

if ($NoConsole) {
    $drawing = New-Object -TypeName System.Reflection.AssemblyName -ArgumentList (
        'System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'
    )

    $forms = New-Object -TypeName System.Reflection.AssemblyName -ArgumentList (
        'System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
    )

    if ($Runtime40) {
        $drawing = New-Object -TypeName System.Reflection.AssemblyName -ArgumentList (
            'System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'
        )

        $forms = New-Object -TypeName System.Reflection.AssemblyName -ArgumentList (
            'System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
        )
    }

    [System.AppDomain]::CurrentDomain.Load($drawing) | Out-Null
    [System.AppDomain]::CurrentDomain.Load($forms) | Out-Null

    $assembies.Add((([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
        $_.ManifestModule.Name -eq 'System.Drawing.dll'
    } | Select-Object -First 1) | Select-Object -ExpandProperty Location))

    $assembies.Add((([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
        $_.ManifestModule.Name -eq 'System.Windows.Forms.dll'
    } | Select-Object -First 1) | Select-Object -ExpandProperty Location))
}


$codeProvider = New-Object -TypeName Microsoft.CSharp.CSharpCodeProvider -ArgumentList $options
$compilerParameters = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters -ArgumentList ($assembies, $OutputFile)

$compilerParameters.GenerateInMemory = $false
$compilerParameters.GenerateExecutable = $true


if ($x64 -and (-not $x86)) { $platform = 'x64' }
elseif ($x86 -and (-not $x64)) { $platform = 'x86' }
else { $platform = 'anycpu' }

if ($NoConsole) { $target = 'winexe' } else { $target =  'exe' }


$iconFileParam = New-Object -TypeName System.Text.StringBuilder

if (-not ([string]::IsNullOrEmpty($IconFile))) {
    [void]$iconFileParam.AppendFormat('"/win32icon:{0}"', $IconFile)
}


$manifestParam = New-Object -TypeName System.Text.StringBuilder
$win32manifest = New-Object -TypeName System.Text.StringBuilder

if ($RequireAdmin -or $SupportOS -or $LongPaths) {
    [void]$manifestParam.AppendFormat('"/win32manifest:{0}.win32manifest', $OutputFile)

    [void]$win32manifest.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$win32manifest.AppendLine('<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">')

    if ($LongPaths) {
        [void]$win32manifest.AppendLine('  <application xmlns="urn:schemas-microsoft-com:asm.v3">')
        [void]$win32manifest.AppendLine('    <windowsSettings>')
        [void]$win32manifest.AppendLine('      <longPathAware xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">true</longPathAware>')
        [void]$win32manifest.AppendLine('    </windowsSettings>')
        [void]$win32manifest.AppendLine('  </application>')
    }

    if ($RequireAdmin) {
        [void]$win32manifest.AppendLine('  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">')
        [void]$win32manifest.AppendLine('  <security>')
        [void]$win32manifest.AppendLine('    <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">')
        [void]$win32manifest.AppendLine('      <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>')
        [void]$win32manifest.AppendLine('    </requestedPrivileges>')
        [void]$win32manifest.AppendLine('  </security>')
        [void]$win32manifest.AppendLine('  </trustInfo>')
    }

    if ($SupportOS) {
        [void]$win32manifest.AppendLine('  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">')
        [void]$win32manifest.AppendLine('    <application>')
        [void]$win32manifest.AppendLine('      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>')
        [void]$win32manifest.AppendLine('      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>')
        [void]$win32manifest.AppendLine('      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>')
        [void]$win32manifest.AppendLine('      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>')
        [void]$win32manifest.AppendLine('      <supportedOS Id="{e2011457-1546-43c5-a5fe-008deee3d3f0}"/>')
        [void]$win32manifest.AppendLine('    </application>')
        [void]$win32manifest.AppendLine('  </compatibility>')
    }

    [void]$win32manifest.AppendLine('</assembly>')

    $win32manifest.ToString() | Set-Content -Path ($OutputFile + '.win32manifest') -Encoding UTF8
}


if (-not $Virtualize) {
    $compilerParameters.CompilerOptions = '/platform:{0} /target:{1} {2} {3}' -f $platform, $target, $iconFileParam.ToString(), $manifestParam.ToString()
}
else {
    Write-Warning 'Application virtualization is activated, forcing x86 platfom.'
    $compilerParameters.CompilerOptions = '/platform:x86 /target:{0} {1} /nowin32manifest' -f $target, $iconFileParam.ToString()
}


$compilerParameters.IncludeDebugInformation = $PSBoundParameters.ContainsKey('Debug')
$compilerParameters.TempFiles.KeepFiles = $PSBoundParameters.ContainsKey('Debug')


Write-Output ('Reading input file {0}' -f $InputFile)

$content = Get-Content -LiteralPath $InputFile -Encoding UTF8 -ErrorAction SilentlyContinue

if ([string]::IsNullOrEmpty($content)) {
    Write-Error 'No data found. May be read error or file protected.'
}

$script = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(
    [System.String]::Join([System.Environment]::NewLine, $content)
))


$culture = New-Object -TypeName System.Text.StringBuilder

if ($null -ne $LCID) {
    [void]$culture.AppendFormat('System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.GetCultureInfo({0});', $LCID).AppendLine()
    [void]$culture.AppendFormat('System.Threading.Thread.CurrentThread.CurrentUICulture = System.Globalization.CultureInfo.GetCultureInfo({0});', $LCID).AppendLine()
}

#endregion


#region Program Framework

$sb = New-Object -TypeName System.Text.StringBuilder

[void]$sb.AppendLine('// Simple PowerShell host created by Ingo Karstein (https://blog.kenaro.com) for PS2EXE')
[void]$sb.AppendLine('// Reworked and GUI support by Markus Scholtes')
[void]$sb.AppendLine('// Refactor by Garrett Dees')

[void]$sb.AppendLine()
[void]$sb.AppendLine('using System;')
[void]$sb.AppendLine('using System.Collections.Generic;')
[void]$sb.AppendLine('using System.Text;')
[void]$sb.AppendLine('using System.Management.Automation;')
[void]$sb.AppendLine('using System.Management.Automation.Runspaces;')
[void]$sb.AppendLine('using PowerShell = System.Management.Automation.PowerShell;')
[void]$sb.AppendLine('using System.Globalization;')
[void]$sb.AppendLine('using System.Management.Automation.Host;')
[void]$sb.AppendLine('using System.Security;')
[void]$sb.AppendLine('using System.Reflection;')
[void]$sb.AppendLine('using System.Runtime.InteropServices;')

if ($NoConsole) {
    [void]$sb.AppendLine('using System.Windows.Forms;')
    [void]$sb.AppendLine('using System.Drawing;')
}

[void]$sb.AppendLine()
[void]$sb.AppendFormat('[assembly: AssemblyTitle("{0}")]', $Title).AppendLine()
[void]$sb.AppendFormat('[assembly: AssemblyProduct("{0}")]', $Product).AppendLine()
[void]$sb.AppendFormat('[assembly: AssemblyCopyright("{0}")]', $Copyright).AppendLine()
[void]$sb.AppendFormat('[assembly: AssemblyTrademark("{0}")]', $Trademark).AppendLine()

if (-not [string]::IsNullOrEmpty($Version)) {
    [void]$sb.AppendFormat('[assembly: AssemblyVersion("{0}")]', $Version).AppendLine()
    [void]$sb.AppendFormat('[assembly: AssemblyFileVersion("{0}")]', $Version).AppendLine()
}

[void]$sb.AppendLine('// not displayed in details tab of properties dialog, but embedded to file')
[void]$sb.AppendFormat('[assembly: AssemblyDescription("{0}")]', $Description).AppendLine()
[void]$sb.AppendFormat('[assembly: AssemblyCompany("{0}")]', $Company).AppendLine()

#region PowerShell Host

[void]$sb.AppendLine()
[void]$sb.AppendLine('namespace ik.PowerShell')
[void]$sb.AppendLine('{')

#region Credential Form

if ($NoConsole -or $CredentialGUI) {
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('    internal class CredentialForm')
    [void]$sb.AppendLine('    {')
    [void]$sb.AppendLine('        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]')
    [void]$sb.AppendLine('        private struct CREDUI_INFO')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            public int cbSize;')
    [void]$sb.AppendLine('            public IntPtr hwndParent;')
    [void]$sb.AppendLine('            public string pszMessageText;')
    [void]$sb.AppendLine('            public string pszCaptionText;')
    [void]$sb.AppendLine('            public IntPtr hbmBanner;')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        [Flags]')
    [void]$sb.AppendLine('        enum CREDUI_FLAGS')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            INCORRECT_PASSWORD = 0x1,')
    [void]$sb.AppendLine('            DO_NOT_PERSIST = 0x2,')
    [void]$sb.AppendLine('            REQUEST_ADMINISTRATOR = 0x4,')
    [void]$sb.AppendLine('            EXCLUDE_CERTIFICATES = 0x8,')
    [void]$sb.AppendLine('            REQUIRE_CERTIFICATE = 0x10,')
    [void]$sb.AppendLine('            SHOW_SAVE_CHECK_BOX = 0x40,')
    [void]$sb.AppendLine('            ALWAYS_SHOW_UI = 0x80,')
    [void]$sb.AppendLine('            REQUIRE_SMARTCARD = 0x100,')
    [void]$sb.AppendLine('            PASSWORD_ONLY_OK = 0x200,')
    [void]$sb.AppendLine('            VALIDATE_USERNAME = 0x400,')
    [void]$sb.AppendLine('            COMPLETE_USERNAME = 0x800,')
    [void]$sb.AppendLine('            PERSIST = 0x1000,')
    [void]$sb.AppendLine('            SERVER_CREDENTIAL = 0x4000,')
    [void]$sb.AppendLine('            EXPECT_CONFIRMATION = 0x20000,')
    [void]$sb.AppendLine('            GENERIC_CREDENTIALS = 0x40000,')
    [void]$sb.AppendLine('            USERNAME_TARGET_CREDENTIALS = 0x80000,')
    [void]$sb.AppendLine('            KEEP_USERNAME = 0x100000,')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public enum CredUIReturnCodes')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            NO_ERROR = 0,')
    [void]$sb.AppendLine('            ERROR_CANCELLED = 1223,')
    [void]$sb.AppendLine('            ERROR_NO_SUCH_LOGON_SESSION = 1312,')
    [void]$sb.AppendLine('            ERROR_NOT_FOUND = 1168,')
    [void]$sb.AppendLine('            ERROR_INVALID_ACCOUNT_NAME = 1315,')
    [void]$sb.AppendLine('            ERROR_INSUFFICIENT_BUFFER = 122,')
    [void]$sb.AppendLine('            ERROR_INVALID_PARAMETER = 87,')
    [void]$sb.AppendLine('            ERROR_INVALID_FLAGS = 1004,')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        [DllImport("credui", CharSet = CharSet.Unicode)]')
    [void]$sb.AppendLine('        private static extern CredUIReturnCodes CredUIPromptForCredentials(ref CREDUI_INFO creditUR,')
    [void]$sb.AppendLine('            string targetName,')
    [void]$sb.AppendLine('            IntPtr reserved1,')
    [void]$sb.AppendLine('            int iError,')
    [void]$sb.AppendLine('            StringBuilder userName,')
    [void]$sb.AppendLine('            int maxUserName,')
    [void]$sb.AppendLine('            StringBuilder password,')
    [void]$sb.AppendLine('            int maxPassword,')
    [void]$sb.AppendLine('            [MarshalAs(UnmanagedType.Bool)] ref bool pfSave,')
    [void]$sb.AppendLine('            CREDUI_FLAGS flags);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public class UserPwd')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            public string User = string.Empty;')
    [void]$sb.AppendLine('            public string Password = string.Empty;')
    [void]$sb.AppendLine('            public string Domain = string.Empty;')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        internal static UserPwd PromptForPassword(string caption, string message, string target, string user, PSCredentialTypes credTypes, PSCredentialUIOptions options)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            // Flags und Variablen initialisieren')
    [void]$sb.AppendLine('            StringBuilder userPassword = new StringBuilder(), userID = new StringBuilder(user, 128);')
    [void]$sb.AppendLine('            CREDUI_INFO credUI = new CREDUI_INFO();')
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(message)) credUI.pszMessageText = message;')
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(caption)) credUI.pszCaptionText = caption;')
    [void]$sb.AppendLine('            credUI.cbSize = Marshal.SizeOf(credUI);')
    [void]$sb.AppendLine('            bool save = false;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            CREDUI_FLAGS flags = CREDUI_FLAGS.DO_NOT_PERSIST;')
    [void]$sb.AppendLine('            if ((credTypes & PSCredentialTypes.Generic) == PSCredentialTypes.Generic)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                flags |= CREDUI_FLAGS.GENERIC_CREDENTIALS;')
    [void]$sb.AppendLine('                if ((options & PSCredentialUIOptions.AlwaysPrompt) == PSCredentialUIOptions.AlwaysPrompt)')
    [void]$sb.AppendLine('                {')
    [void]$sb.AppendLine('                    flags |= CREDUI_FLAGS.ALWAYS_SHOW_UI;')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // den Benutzer nach Kennwort fragen, grafischer Prompt')
    [void]$sb.AppendLine('            CredUIReturnCodes returnCode = CredUIPromptForCredentials(ref credUI, target, IntPtr.Zero, 0, userID, 128, userPassword, 128, ref save, flags);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (returnCode == CredUIReturnCodes.NO_ERROR)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                UserPwd ret = new UserPwd();')
    [void]$sb.AppendLine('                ret.User = userID.ToString();')
    [void]$sb.AppendLine('                ret.Password = userPassword.ToString();')
    [void]$sb.AppendLine('                ret.Domain = "";')
    [void]$sb.AppendLine('                return ret;')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            return null;')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('    }')
}

#endregion

#region PS2EXE Host Raw User Interface

[void]$sb.AppendLine()
[void]$sb.AppendLine('    internal class PS2EXEHostRawUI : PSHostRawUserInterface')
[void]$sb.AppendLine('    {')

if ($NoConsole) {
    [void]$sb.AppendLine('        // Speicher für Konsolenfarben bei GUI-Output werden gelesen und gesetzt, aber im Moment nicht genutzt (for future use)')
    [void]$sb.AppendLine('        private ConsoleColor ncBackgroundColor = ConsoleColor.White;')
    [void]$sb.AppendLine('        private ConsoleColor ncForegroundColor = ConsoleColor.Black;')
}
else {
    [void]$sb.AppendLine('        const int STD_OUTPUT_HANDLE = -11;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        //CHAR_INFO struct, which was a union in the old days')
    [void]$sb.AppendLine('        // so we want to use LayoutKind.Explicit to mimic it as closely')
    [void]$sb.AppendLine('        // as we can')
    [void]$sb.AppendLine('        [StructLayout(LayoutKind.Explicit)]')
    [void]$sb.AppendLine('        public struct CHAR_INFO')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            [FieldOffset(0)]')
    [void]$sb.AppendLine('            internal char UnicodeChar;')
    [void]$sb.AppendLine('            [FieldOffset(0)]')
    [void]$sb.AppendLine('            internal char AsciiChar;')
    [void]$sb.AppendLine('            [FieldOffset(2)] //2 bytes seems to work properly')
    [void]$sb.AppendLine('            internal UInt16 Attributes;')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        //COORD struct')
    [void]$sb.AppendLine('        [StructLayout(LayoutKind.Sequential)]')
    [void]$sb.AppendLine('        public struct COORD')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            public short X;')
    [void]$sb.AppendLine('            public short Y;')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        //SMALL_RECT struct')
    [void]$sb.AppendLine('        [StructLayout(LayoutKind.Sequential)]')
    [void]$sb.AppendLine('        public struct SMALL_RECT')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            public short Left;')
    [void]$sb.AppendLine('            public short Top;')
    [void]$sb.AppendLine('            public short Right;')
    [void]$sb.AppendLine('            public short Bottom;')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        /* Reads character and color attribute data from a rectangular block of character cells in a console screen buffer,')
    [void]$sb.AppendLine('             and the function writes the data to a rectangular block at a specified location in the destination buffer. */')
    [void]$sb.AppendLine('        [DllImport("kernel32.dll", EntryPoint = "ReadConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]')
    [void]$sb.AppendLine('        internal static extern bool ReadConsoleOutput(')
    [void]$sb.AppendLine('            IntPtr hConsoleOutput,')
    [void]$sb.AppendLine('            /* This pointer is treated as the origin of a two-dimensional array of CHAR_INFO structures')
    [void]$sb.AppendLine('            whose size is specified by the dwBufferSize parameter.*/')
    [void]$sb.AppendLine('            [MarshalAs(UnmanagedType.LPArray), Out] CHAR_INFO[,] lpBuffer,')
    [void]$sb.AppendLine('            COORD dwBufferSize,')
    [void]$sb.AppendLine('            COORD dwBufferCoord,')
    [void]$sb.AppendLine('            ref SMALL_RECT lpReadRegion);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        /* Writes character and color attribute data to a specified rectangular block of character cells in a console screen buffer.')
    [void]$sb.AppendLine('            The data to be written is taken from a correspondingly sized rectangular block at a specified location in the source buffer */')
    [void]$sb.AppendLine('        [DllImport("kernel32.dll", EntryPoint = "WriteConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]')
    [void]$sb.AppendLine('        internal static extern bool WriteConsoleOutput(')
    [void]$sb.AppendLine('            IntPtr hConsoleOutput,')
    [void]$sb.AppendLine('            /* This pointer is treated as the origin of a two-dimensional array of CHAR_INFO structures')
    [void]$sb.AppendLine('            whose size is specified by the dwBufferSize parameter.*/')
    [void]$sb.AppendLine('            [MarshalAs(UnmanagedType.LPArray), In] CHAR_INFO[,] lpBuffer,')
    [void]$sb.AppendLine('            COORD dwBufferSize,')
    [void]$sb.AppendLine('            COORD dwBufferCoord,')
    [void]$sb.AppendLine('            ref SMALL_RECT lpWriteRegion);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        /* Moves a block of data in a screen buffer. The effects of the move can be limited by specifying a clipping rectangle, so')
    [void]$sb.AppendLine('            the contents of the console screen buffer outside the clipping rectangle are unchanged. */')
    [void]$sb.AppendLine('        [DllImport("kernel32.dll", SetLastError = true)]')
    [void]$sb.AppendLine('        static extern bool ScrollConsoleScreenBuffer(')
    [void]$sb.AppendLine('            IntPtr hConsoleOutput,')
    [void]$sb.AppendLine('            [In] ref SMALL_RECT lpScrollRectangle,')
    [void]$sb.AppendLine('            [In] ref SMALL_RECT lpClipRectangle,')
    [void]$sb.AppendLine('            COORD dwDestinationOrigin,')
    [void]$sb.AppendLine('            [In] ref CHAR_INFO lpFill);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        [DllImport("kernel32.dll", SetLastError = true)]')
    [void]$sb.AppendLine('        static extern IntPtr GetStdHandle(int nStdHandle);')
}


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override ConsoleColor BackgroundColor')
[void]$sb.AppendLine('        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            get { return Console.BackgroundColor; }')
    [void]$sb.AppendLine('            set { Console.BackgroundColor = value; }')
}
else {
    [void]$sb.AppendLine('            get { return ncBackgroundColor; }')
    [void]$sb.AppendLine('            set { ncBackgroundColor = value; }')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override System.Management.Automation.Host.Size BufferSize')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                if (ConsoleInfo.IsOutputRedirected())')
    [void]$sb.AppendLine('                    // return default value for redirection. If no valid value is returned WriteLine will not be called')
    [void]$sb.AppendLine('                    return new System.Management.Automation.Host.Size(120, 50);')
    [void]$sb.AppendLine('                else')
    [void]$sb.AppendLine('                    return new System.Management.Automation.Host.Size(Console.BufferWidth, Console.BufferHeight);')
}
else {
    [void]$sb.AppendLine('                // return default value for Winforms. If no valid value is returned WriteLine will not be called')
    [void]$sb.AppendLine('                return new System.Management.Automation.Host.Size(120, 50);')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            set')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                Console.BufferWidth = value.Width;')
    [void]$sb.AppendLine('                Console.BufferHeight = value.Height;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override Coordinates CursorPosition')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                return new Coordinates(Console.CursorLeft, Console.CursorTop);')
}
else {
    [void]$sb.AppendLine('                // Dummywert für Winforms zurückgeben.')
    [void]$sb.AppendLine('                return new Coordinates(0, 0);')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            set')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                Console.CursorTop = value.Y;')
    [void]$sb.AppendLine('                Console.CursorLeft = value.X;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override int CursorSize')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                return Console.CursorSize;')
}
else {
    [void]$sb.AppendLine('                // Dummywert für Winforms zurückgeben.')
    [void]$sb.AppendLine('                return 25;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            set')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                Console.CursorSize = value;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')


if ($NoConsole){
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        private Form InvisibleForm = null;')
}


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void FlushInputBuffer()')
[void]$sb.AppendLine('        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            if (!ConsoleInfo.IsInputRedirected())')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                while (Console.KeyAvailable)')
    [void]$sb.AppendLine('                    Console.ReadKey(true);')
    [void]$sb.AppendLine('            }')
}
else {
    [void]$sb.AppendLine('            if (InvisibleForm != null)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                InvisibleForm.Close();')
    [void]$sb.AppendLine('                InvisibleForm = null;')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                InvisibleForm = new Form();')
    [void]$sb.AppendLine('                InvisibleForm.Opacity = 0;')
    [void]$sb.AppendLine('                InvisibleForm.ShowInTaskbar = false;')
    [void]$sb.AppendLine('                InvisibleForm.Visible = true;')
    [void]$sb.AppendLine('            }')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override ConsoleColor ForegroundColor')
[void]$sb.AppendLine('        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            get { return Console.ForegroundColor; }')
    [void]$sb.AppendLine('            set { Console.ForegroundColor = value; }')
} else {
    [void]$sb.AppendLine('            get { return ncForegroundColor; }')
    [void]$sb.AppendLine('            set { ncForegroundColor = value; }')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override BufferCell[,] GetBufferContents(System.Management.Automation.Host.Rectangle rectangle)')
[void]$sb.AppendLine('        {')

if ($Compiler20) {
    [void]$sb.AppendLine('            throw new Exception("Method GetBufferContents not implemented for .Net V2.0 compiler");')
}
else {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);')
        [void]$sb.AppendLine('            CHAR_INFO[,] buffer = new CHAR_INFO[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];')
        [void]$sb.AppendLine('            COORD buffer_size = new COORD() { X = (short)(rectangle.Right - rectangle.Left + 1), Y = (short)(rectangle.Bottom - rectangle.Top + 1) };')
        [void]$sb.AppendLine('            COORD buffer_index = new COORD() { X = 0, Y = 0 };')
        [void]$sb.AppendLine('            SMALL_RECT screen_rect = new SMALL_RECT() { Left = (short)rectangle.Left, Top = (short)rectangle.Top, Right = (short)rectangle.Right, Bottom = (short)rectangle.Bottom };')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            ReadConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            System.Management.Automation.Host.BufferCell[,] ScreenBuffer = new System.Management.Automation.Host.BufferCell[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];')
        [void]$sb.AppendLine('            for (int y = 0; y <= rectangle.Bottom - rectangle.Top; y++)')
        [void]$sb.AppendLine('                for (int x = 0; x <= rectangle.Right - rectangle.Left; x++)')
        [void]$sb.AppendLine('                {')
        [void]$sb.AppendLine('                    ScreenBuffer[y, x] = new System.Management.Automation.Host.BufferCell(buffer[y, x].AsciiChar, (System.ConsoleColor)(buffer[y, x].Attributes & 0xF), (System.ConsoleColor)((buffer[y, x].Attributes & 0xF0) / 0x10), System.Management.Automation.Host.BufferCellType.Complete);')
        [void]$sb.AppendLine('                }')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            return ScreenBuffer;')
    }
    else {
        [void]$sb.AppendLine('            System.Management.Automation.Host.BufferCell[,] ScreenBuffer = new System.Management.Automation.Host.BufferCell[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            for (int y = 0; y <= rectangle.Bottom - rectangle.Top; y++)')
        [void]$sb.AppendLine('                for (int x = 0; x <= rectangle.Right - rectangle.Left; x++)')
        [void]$sb.AppendLine('                {')
        [void]$sb.AppendLine('                    ScreenBuffer[y, x] = new System.Management.Automation.Host.BufferCell('' '', ncForegroundColor, ncBackgroundColor, System.Management.Automation.Host.BufferCellType.Complete);')
        [void]$sb.AppendLine('                }')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            return ScreenBuffer;')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override bool KeyAvailable')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                return Console.KeyAvailable;')
}
else {
    [void]$sb.AppendLine('                return true;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override System.Management.Automation.Host.Size MaxPhysicalWindowSize')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                return new System.Management.Automation.Host.Size(Console.LargestWindowWidth, Console.LargestWindowHeight);')
}
else {
    [void]$sb.AppendLine('                // Dummy-Wert für Winforms')
    [void]$sb.AppendLine('                return new System.Management.Automation.Host.Size(240, 84);')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override System.Management.Automation.Host.Size MaxWindowSize')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                return new System.Management.Automation.Host.Size(Console.BufferWidth, Console.BufferWidth);')
}
else {
    [void]$sb.AppendLine('                // Dummy-Wert für Winforms')
    [void]$sb.AppendLine('                return new System.Management.Automation.Host.Size(120, 84);')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override KeyInfo ReadKey(ReadKeyOptions options)')
[void]$sb.AppendLine('        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            ConsoleKeyInfo cki = Console.ReadKey((options & ReadKeyOptions.NoEcho) != 0);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            ControlKeyStates cks = 0;')
    [void]$sb.AppendLine('            if ((cki.Modifiers & ConsoleModifiers.Alt) != 0)')
    [void]$sb.AppendLine('                cks |= ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;')
    [void]$sb.AppendLine('            if ((cki.Modifiers & ConsoleModifiers.Control) != 0)')
    [void]$sb.AppendLine('                cks |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;')
    [void]$sb.AppendLine('            if ((cki.Modifiers & ConsoleModifiers.Shift) != 0)')
    [void]$sb.AppendLine('                cks |= ControlKeyStates.ShiftPressed;')
    [void]$sb.AppendLine('            if (Console.CapsLock)')
    [void]$sb.AppendLine('                cks |= ControlKeyStates.CapsLockOn;')
    [void]$sb.AppendLine('            if (Console.NumberLock)')
    [void]$sb.AppendLine('                cks |= ControlKeyStates.NumLockOn;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            return new KeyInfo((int)cki.Key, cki.KeyChar, cks, (options & ReadKeyOptions.IncludeKeyDown) != 0);')
}
else {
    [void]$sb.AppendLine('            if ((options & ReadKeyOptions.IncludeKeyDown) != 0)')
    [void]$sb.AppendLine('                return ReadKeyBox.Show("", "", true);')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                return ReadKeyBox.Show("", "", false);')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void ScrollBufferContents(System.Management.Automation.Host.Rectangle source, Coordinates destination, System.Management.Automation.Host.Rectangle clip, BufferCell fill)')
[void]$sb.AppendLine('        { // no destination block clipping implemented')

if (-not $NoConsole) {
    if ($Compiler20) {
        [void]$sb.AppendLine('            throw new Exception("Method ScrollBufferContents not implemented for .Net V2.0 compiler");')
    }
    else {
        [void]$sb.AppendLine('            // clip area out of source range?')
        [void]$sb.AppendLine('            if ((source.Left > clip.Right) || (source.Right < clip.Left) || (source.Top > clip.Bottom) || (source.Bottom < clip.Top))')
        [void]$sb.AppendLine('            { // clipping out of range -> nothing to do')
        [void]$sb.AppendLine('                return;')
        [void]$sb.AppendLine('            }')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);')
        [void]$sb.AppendLine('            SMALL_RECT lpScrollRectangle = new SMALL_RECT() { Left = (short)source.Left, Top = (short)source.Top, Right = (short)(source.Right), Bottom = (short)(source.Bottom) };')
        [void]$sb.AppendLine('            SMALL_RECT lpClipRectangle;')
        [void]$sb.AppendLine('            if (clip != null)')
        [void]$sb.AppendLine('            { lpClipRectangle = new SMALL_RECT() { Left = (short)clip.Left, Top = (short)clip.Top, Right = (short)(clip.Right), Bottom = (short)(clip.Bottom) }; }')
        [void]$sb.AppendLine('            else')
        [void]$sb.AppendLine('            { lpClipRectangle = new SMALL_RECT() { Left = (short)0, Top = (short)0, Right = (short)(Console.WindowWidth - 1), Bottom = (short)(Console.WindowHeight - 1) }; }')
        [void]$sb.AppendLine('            COORD dwDestinationOrigin = new COORD() { X = (short)(destination.X), Y = (short)(destination.Y) };')
        [void]$sb.AppendLine('            CHAR_INFO lpFill = new CHAR_INFO() { AsciiChar = fill.Character, Attributes = (ushort)((int)(fill.ForegroundColor) + (int)(fill.BackgroundColor) * 16) };')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            ScrollConsoleScreenBuffer(hStdOut, ref lpScrollRectangle, ref lpClipRectangle, dwDestinationOrigin, ref lpFill);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void SetBufferContents(System.Management.Automation.Host.Rectangle rectangle, BufferCell fill)')
[void]$sb.AppendLine('        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            // using a trick: move the buffer out of the screen, the source area gets filled with the char fill.Character')
    [void]$sb.AppendLine('            if (rectangle.Left >= 0)')
    [void]$sb.AppendLine('                Console.MoveBufferArea(rectangle.Left, rectangle.Top, rectangle.Right - rectangle.Left + 1, rectangle.Bottom - rectangle.Top + 1, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('            { // Clear-Host: move all content off the screen')
    [void]$sb.AppendLine('                Console.MoveBufferArea(0, 0, BufferSize.Width, BufferSize.Height, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);')
    [void]$sb.AppendLine('            }')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void SetBufferContents(Coordinates origin, BufferCell[,] contents)')
[void]$sb.AppendLine('        {')

if (-not $NoConsole) {
    if ($Compiler20) {
        [void]$sb.AppendLine('            throw new Exception("Method SetBufferContents not implemented for .Net V2.0 compiler");')
    }
    else {
        [void]$sb.AppendLine('            IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);')
        [void]$sb.AppendLine('            CHAR_INFO[,] buffer = new CHAR_INFO[contents.GetLength(0), contents.GetLength(1)];')
        [void]$sb.AppendLine('            COORD buffer_size = new COORD() { X = (short)(contents.GetLength(1)), Y = (short)(contents.GetLength(0)) };')
        [void]$sb.AppendLine('            COORD buffer_index = new COORD() { X = 0, Y = 0 };')
        [void]$sb.AppendLine('            SMALL_RECT screen_rect = new SMALL_RECT() { Left = (short)origin.X, Top = (short)origin.Y, Right = (short)(origin.X + contents.GetLength(1) - 1), Bottom = (short)(origin.Y + contents.GetLength(0) - 1) };')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            for (int y = 0; y < contents.GetLength(0); y++)')
        [void]$sb.AppendLine('                for (int x = 0; x < contents.GetLength(1); x++)')
        [void]$sb.AppendLine('                {')
        [void]$sb.AppendLine('                    buffer[y, x] = new CHAR_INFO() { AsciiChar = contents[y, x].Character, Attributes = (ushort)((int)(contents[y, x].ForegroundColor) + (int)(contents[y, x].BackgroundColor) * 16) };')
        [void]$sb.AppendLine('                }')

        [void]$sb.AppendLine()
        [void]$sb.AppendLine('            WriteConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override Coordinates WindowPosition')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                Coordinates s = new Coordinates();')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                s.X = Console.WindowLeft;')
    [void]$sb.AppendLine('                s.Y = Console.WindowTop;')
}
else {
    [void]$sb.AppendLine('                // Dummy-Wert für Winforms')
    [void]$sb.AppendLine('                s.X = 0;')
    [void]$sb.AppendLine('                s.Y = 0;')
}

[void]$sb.AppendLine('                return s;')
[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            set')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                Console.WindowLeft = value.X;')
    [void]$sb.AppendLine('                Console.WindowTop = value.Y;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override System.Management.Automation.Host.Size WindowSize')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                System.Management.Automation.Host.Size s = new System.Management.Automation.Host.Size();')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                s.Height = Console.WindowHeight;')
    [void]$sb.AppendLine('                s.Width = Console.WindowWidth;')
}
else {
    [void]$sb.AppendLine('                // Dummy-Wert für Winforms')
    [void]$sb.AppendLine('                s.Height = 50;')
    [void]$sb.AppendLine('                s.Width = 120;')
}

[void]$sb.AppendLine('                return s;')
[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            set')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                Console.WindowWidth = value.Width;')
    [void]$sb.AppendLine('                Console.WindowHeight = value.Height;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override string WindowTitle')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                return Console.Title;')
}
else {
    [void]$sb.AppendLine('                return System.AppDomain.CurrentDomain.FriendlyName;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            set')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                Console.Title = value;')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')
[void]$sb.AppendLine('    }')

#endregion

#region Graphical User Interface

if ($NoConsole) {
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('    public class InputBox')
    [void]$sb.AppendLine('    {')
    [void]$sb.AppendLine('        [DllImport("user32.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]')
    [void]$sb.AppendLine('        private static extern IntPtr MB_GetString(uint strId);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public static DialogResult Show(string sTitle, string sPrompt, ref string sValue, bool bSecure)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            // Generate controls')
    [void]$sb.AppendLine('            Form form = new Form();')
    [void]$sb.AppendLine('            Label label = new Label();')
    [void]$sb.AppendLine('            TextBox textBox = new TextBox();')
    [void]$sb.AppendLine('            Button buttonOk = new Button();')
    [void]$sb.AppendLine('            Button buttonCancel = new Button();')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Sizes and positions are defined according to the label')
    [void]$sb.AppendLine('            // This control has to be finished first')
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(sPrompt))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                if (bSecure)')
    [void]$sb.AppendLine('                    label.Text = "Secure input:   ";')
    [void]$sb.AppendLine('                else')
    [void]$sb.AppendLine('                    label.Text = "Input:          ";')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                label.Text = sPrompt;')
    [void]$sb.AppendLine('            label.Location = new Point(9, 19);')
    [void]$sb.AppendLine('            label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);')
    [void]$sb.AppendLine('            label.AutoSize = true;')
    [void]$sb.AppendLine('            // Size of the label is defined not before Add()')
    [void]$sb.AppendLine('            form.Controls.Add(label);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Generate textbox')
    [void]$sb.AppendLine('            if (bSecure) textBox.UseSystemPasswordChar = true;')
    [void]$sb.AppendLine('            textBox.Text = sValue;')
    [void]$sb.AppendLine('            textBox.SetBounds(12, label.Bottom, label.Right - 12, 20);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Generate buttons')
    [void]$sb.AppendLine('            // get localized "OK"-string')
    [void]$sb.AppendLine('            string sTextOK = Marshal.PtrToStringUni(MB_GetString(0));')
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(sTextOK))')
    [void]$sb.AppendLine('                buttonOk.Text = "OK";')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                buttonOk.Text = sTextOK;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // get localized "Cancel"-string')
    [void]$sb.AppendLine('            string sTextCancel = Marshal.PtrToStringUni(MB_GetString(1));')
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(sTextCancel))')
    [void]$sb.AppendLine('                buttonCancel.Text = "Cancel";')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                buttonCancel.Text = sTextCancel;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            buttonOk.DialogResult = DialogResult.OK;')
    [void]$sb.AppendLine('            buttonCancel.DialogResult = DialogResult.Cancel;')
    [void]$sb.AppendLine('            buttonOk.SetBounds(System.Math.Max(12, label.Right - 158), label.Bottom + 36, 75, 23);')
    [void]$sb.AppendLine('            buttonCancel.SetBounds(System.Math.Max(93, label.Right - 77), label.Bottom + 36, 75, 23);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Configure form')
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(sTitle))')
    [void]$sb.AppendLine('                form.Text = System.AppDomain.CurrentDomain.FriendlyName;')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                form.Text = sTitle;')
    [void]$sb.AppendLine('            form.ClientSize = new System.Drawing.Size(System.Math.Max(178, label.Right + 10), label.Bottom + 71);')
    [void]$sb.AppendLine('            form.Controls.AddRange(new Control[] { textBox, buttonOk, buttonCancel });')
    [void]$sb.AppendLine('            form.FormBorderStyle = FormBorderStyle.FixedDialog;')
    [void]$sb.AppendLine('            form.StartPosition = FormStartPosition.CenterScreen;')
    [void]$sb.AppendLine('            try')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            catch')
    [void]$sb.AppendLine('            { }')
    [void]$sb.AppendLine('            form.MinimizeBox = false;')
    [void]$sb.AppendLine('            form.MaximizeBox = false;')
    [void]$sb.AppendLine('            form.AcceptButton = buttonOk;')
    [void]$sb.AppendLine('            form.CancelButton = buttonCancel;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Show form and compute results')
    [void]$sb.AppendLine('            DialogResult dialogResult = form.ShowDialog();')
    [void]$sb.AppendLine('            sValue = textBox.Text;')
    [void]$sb.AppendLine('            return dialogResult;')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public static DialogResult Show(string sTitle, string sPrompt, ref string sValue)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            return Show(sTitle, sPrompt, ref sValue, false);')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('    }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('    public class ChoiceBox')
    [void]$sb.AppendLine('    {')
    [void]$sb.AppendLine('        public static int Show(System.Collections.ObjectModel.Collection<ChoiceDescription> aAuswahl, int iVorgabe, string sTitle, string sPrompt)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            // cancel if array is empty')
    [void]$sb.AppendLine('            if (aAuswahl == null) return -1;')
    [void]$sb.AppendLine('            if (aAuswahl.Count < 1) return -1;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Generate controls')
    [void]$sb.AppendLine('            Form form = new Form();')
    [void]$sb.AppendLine('            RadioButton[] aradioButton = new RadioButton[aAuswahl.Count];')
    [void]$sb.AppendLine('            ToolTip toolTip = new ToolTip();')
    [void]$sb.AppendLine('            Button buttonOk = new Button();')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Sizes and positions are defined according to the label')
    [void]$sb.AppendLine('            // This control has to be finished first when a prompt is available')
    [void]$sb.AppendLine('            int iPosY = 19, iMaxX = 0;')
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(sPrompt))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                Label label = new Label();')
    [void]$sb.AppendLine('                label.Text = sPrompt;')
    [void]$sb.AppendLine('                label.Location = new Point(9, 19);')
    [void]$sb.AppendLine('                label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);')
    [void]$sb.AppendLine('                label.AutoSize = true;')
    [void]$sb.AppendLine('                // erst durch Add() wird die Größe des Labels ermittelt')
    [void]$sb.AppendLine('                form.Controls.Add(label);')
    [void]$sb.AppendLine('                iPosY = label.Bottom;')
    [void]$sb.AppendLine('                iMaxX = label.Right;')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // An den Radiobuttons orientieren sich die weiteren Größen und Positionen')
    [void]$sb.AppendLine('            // Diese Controls also jetzt fertigstellen')
    [void]$sb.AppendLine('            int Counter = 0;')
    [void]$sb.AppendLine('            int tempWidth = System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18;')
    [void]$sb.AppendLine('            foreach (ChoiceDescription sAuswahl in aAuswahl)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                aradioButton[Counter] = new RadioButton();')
    [void]$sb.AppendLine('                aradioButton[Counter].Text = sAuswahl.Label;')
    [void]$sb.AppendLine('                if (Counter == iVorgabe)')
    [void]$sb.AppendLine('                    aradioButton[Counter].Checked = true;')
    [void]$sb.AppendLine('                aradioButton[Counter].Location = new Point(9, iPosY);')
    [void]$sb.AppendLine('                aradioButton[Counter].AutoSize = true;')
    [void]$sb.AppendLine('                // erst durch Add() wird die Größe des Labels ermittelt')
    [void]$sb.AppendLine('                form.Controls.Add(aradioButton[Counter]);')
    [void]$sb.AppendLine('                if (aradioButton[Counter].Width > tempWidth)')
    [void]$sb.AppendLine('                { // radio field to wide for screen -> make two lines')
    [void]$sb.AppendLine('                    int tempHeight = aradioButton[Counter].Height;')
    [void]$sb.AppendLine('                    aradioButton[Counter].Height = tempHeight * (1 + (aradioButton[Counter].Width - 1) / tempWidth);')
    [void]$sb.AppendLine('                    aradioButton[Counter].Width = tempWidth;')
    [void]$sb.AppendLine('                    aradioButton[Counter].AutoSize = false;')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('                iPosY = aradioButton[Counter].Bottom;')
    [void]$sb.AppendLine('                if (aradioButton[Counter].Right > iMaxX) { iMaxX = aradioButton[Counter].Right; }')
    [void]$sb.AppendLine('                if (!string.IsNullOrEmpty(sAuswahl.HelpMessage))')
    [void]$sb.AppendLine('                    toolTip.SetToolTip(aradioButton[Counter], sAuswahl.HelpMessage);')
    [void]$sb.AppendLine('                Counter++;')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Tooltip auch anzeigen, wenn Parent-Fenster inaktiv ist')
    [void]$sb.AppendLine('            toolTip.ShowAlways = true;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Button erzeugen')
    [void]$sb.AppendLine('            buttonOk.Text = "OK";')
    [void]$sb.AppendLine('            buttonOk.DialogResult = DialogResult.OK;')
    [void]$sb.AppendLine('            buttonOk.SetBounds(System.Math.Max(12, iMaxX - 77), iPosY + 36, 75, 23);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // configure form')
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(sTitle))')
    [void]$sb.AppendLine('                form.Text = System.AppDomain.CurrentDomain.FriendlyName;')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                form.Text = sTitle;')
    [void]$sb.AppendLine('            form.ClientSize = new System.Drawing.Size(System.Math.Max(178, iMaxX + 10), iPosY + 71);')
    [void]$sb.AppendLine('            form.Controls.Add(buttonOk);')
    [void]$sb.AppendLine('            form.FormBorderStyle = FormBorderStyle.FixedDialog;')
    [void]$sb.AppendLine('            form.StartPosition = FormStartPosition.CenterScreen;')
    [void]$sb.AppendLine('            try')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            catch')
    [void]$sb.AppendLine('            { }')
    [void]$sb.AppendLine('            form.MinimizeBox = false;')
    [void]$sb.AppendLine('            form.MaximizeBox = false;')
    [void]$sb.AppendLine('            form.AcceptButton = buttonOk;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // show and compute form')
    [void]$sb.AppendLine('            if (form.ShowDialog() == DialogResult.OK)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                int iRueck = -1;')
    [void]$sb.AppendLine('                for (Counter = 0; Counter < aAuswahl.Count; Counter++)')
    [void]$sb.AppendLine('                {')
    [void]$sb.AppendLine('                    if (aradioButton[Counter].Checked == true)')
    [void]$sb.AppendLine('                    { iRueck = Counter; }')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('                return iRueck;')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                return -1;')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('    }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('    public class ReadKeyBox')
    [void]$sb.AppendLine('    {')
    [void]$sb.AppendLine('        [DllImport("user32.dll")]')
    [void]$sb.AppendLine('        public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState,')
    [void]$sb.AppendLine('            [Out, MarshalAs(UnmanagedType.LPWStr, SizeConst = 64)] System.Text.StringBuilder pwszBuff,')
    [void]$sb.AppendLine('            int cchBuff, uint wFlags);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        static string GetCharFromKeys(Keys keys, bool bShift, bool bAltGr)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            System.Text.StringBuilder buffer = new System.Text.StringBuilder(64);')
    [void]$sb.AppendLine('            byte[] keyboardState = new byte[256];')
    [void]$sb.AppendLine('            if (bShift)')
    [void]$sb.AppendLine('            { keyboardState[(int)Keys.ShiftKey] = 0xff; }')
    [void]$sb.AppendLine('            if (bAltGr)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                keyboardState[(int)Keys.ControlKey] = 0xff;')
    [void]$sb.AppendLine('                keyboardState[(int)Keys.Menu] = 0xff;')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            if (ToUnicode((uint) keys, 0, keyboardState, buffer, 64, 0) >= 1)')
    [void]$sb.AppendLine('                return buffer.ToString();')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                return "\0";')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        class KeyboardForm : Form')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            public KeyboardForm()')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                this.KeyDown += new KeyEventHandler(KeyboardForm_KeyDown);')
    [void]$sb.AppendLine('                this.KeyUp += new KeyEventHandler(KeyboardForm_KeyUp);')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // check for KeyDown or KeyUp?')
    [void]$sb.AppendLine('            public bool checkKeyDown = true;')
    [void]$sb.AppendLine('            // key code for pressed key')
    [void]$sb.AppendLine('            public KeyInfo keyinfo;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            void KeyboardForm_KeyDown(object sender, KeyEventArgs e)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                if (checkKeyDown)')
    [void]$sb.AppendLine('                { // store key info')
    [void]$sb.AppendLine('                    keyinfo.VirtualKeyCode = e.KeyValue;')
    [void]$sb.AppendLine('                    keyinfo.Character = GetCharFromKeys(e.KeyCode, e.Shift, e.Alt & e.Control)[0];')
    [void]$sb.AppendLine('                    keyinfo.KeyDown = false;')
    [void]$sb.AppendLine('                    keyinfo.ControlKeyState = 0;')
    [void]$sb.AppendLine('                    if (e.Alt) { keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed; }')
    [void]$sb.AppendLine('                    if (e.Control)')
    [void]$sb.AppendLine('                    {')
    [void]$sb.AppendLine('                        keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;')
    [void]$sb.AppendLine('                        if (!e.Alt)')
    [void]$sb.AppendLine('                        { if (e.KeyValue > 64 && e.KeyValue < 96) keyinfo.Character = (char)(e.KeyValue - 64); }')
    [void]$sb.AppendLine('                    }')
    [void]$sb.AppendLine('                    if (e.Shift) { keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed; }')
    [void]$sb.AppendLine('                    if ((e.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn; }')
    [void]$sb.AppendLine('                    if ((e.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn; }')
    [void]$sb.AppendLine('                    // and close the form')
    [void]$sb.AppendLine('                    this.Close();')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            void KeyboardForm_KeyUp(object sender, KeyEventArgs e)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                if (!checkKeyDown)')
    [void]$sb.AppendLine('                { // store key info')
    [void]$sb.AppendLine('                    keyinfo.VirtualKeyCode = e.KeyValue;')
    [void]$sb.AppendLine('                    keyinfo.Character = GetCharFromKeys(e.KeyCode, e.Shift, e.Alt & e.Control)[0];')
    [void]$sb.AppendLine('                    keyinfo.KeyDown = true;')
    [void]$sb.AppendLine('                    keyinfo.ControlKeyState = 0;')
    [void]$sb.AppendLine('                    if (e.Alt) { keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed; }')
    [void]$sb.AppendLine('                    if (e.Control)')
    [void]$sb.AppendLine('                    {')
    [void]$sb.AppendLine('                        keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;')
    [void]$sb.AppendLine('                        if (!e.Alt)')
    [void]$sb.AppendLine('                        { if (e.KeyValue > 64 && e.KeyValue < 96) keyinfo.Character = (char)(e.KeyValue - 64); }')
    [void]$sb.AppendLine('                    }')
    [void]$sb.AppendLine('                    if (e.Shift) { keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed; }')
    [void]$sb.AppendLine('                    if ((e.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn; }')
    [void]$sb.AppendLine('                    if ((e.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn; }')
    [void]$sb.AppendLine('                    // and close the form')
    [void]$sb.AppendLine('                    this.Close();')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public static KeyInfo Show(string sTitle, string sPrompt, bool bIncludeKeyDown)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            // Controls erzeugen')
    [void]$sb.AppendLine('            KeyboardForm form = new KeyboardForm();')
    [void]$sb.AppendLine('            Label label = new Label();')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Am Label orientieren sich die Größen und Positionen')
    [void]$sb.AppendLine('            // Dieses Control also zuerst fertigstellen')
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(sPrompt))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                label.Text = "Press a key";')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                label.Text = sPrompt;')
    [void]$sb.AppendLine('            label.Location = new Point(9, 19);')
    [void]$sb.AppendLine('            label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);')
    [void]$sb.AppendLine('            label.AutoSize = true;')
    [void]$sb.AppendLine('            // erst durch Add() wird die Größe des Labels ermittelt')
    [void]$sb.AppendLine('            form.Controls.Add(label);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // configure form')
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(sTitle))')
    [void]$sb.AppendLine('                form.Text = System.AppDomain.CurrentDomain.FriendlyName;')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                form.Text = sTitle;')
    [void]$sb.AppendLine('            form.ClientSize = new System.Drawing.Size(System.Math.Max(178, label.Right + 10), label.Bottom + 55);')
    [void]$sb.AppendLine('            form.FormBorderStyle = FormBorderStyle.FixedDialog;')
    [void]$sb.AppendLine('            form.StartPosition = FormStartPosition.CenterScreen;')
    [void]$sb.AppendLine('            try')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            catch')
    [void]$sb.AppendLine('            { }')
    [void]$sb.AppendLine('            form.MinimizeBox = false;')
    [void]$sb.AppendLine('            form.MaximizeBox = false;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // show and compute form')
    [void]$sb.AppendLine('            form.checkKeyDown = bIncludeKeyDown;')
    [void]$sb.AppendLine('            form.ShowDialog();')
    [void]$sb.AppendLine('            return form.keyinfo;')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('    }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('    public class ProgressForm : Form')
    [void]$sb.AppendLine('    {')
    [void]$sb.AppendLine('        private Label objLblActivity;')
    [void]$sb.AppendLine('        private Label objLblStatus;')
    [void]$sb.AppendLine('        private ProgressBar objProgressBar;')
    [void]$sb.AppendLine('        private Label objLblRemainingTime;')
    [void]$sb.AppendLine('        private Label objLblOperation;')
    [void]$sb.AppendLine('        private ConsoleColor ProgressBarColor = ConsoleColor.DarkCyan;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        private Color DrawingColor(ConsoleColor color)')
    [void]$sb.AppendLine('        {  // convert ConsoleColor to System.Drawing.Color')
    [void]$sb.AppendLine('            switch (color)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                case ConsoleColor.Black: return Color.Black;')
    [void]$sb.AppendLine('                case ConsoleColor.Blue: return Color.Blue;')
    [void]$sb.AppendLine('                case ConsoleColor.Cyan: return Color.Cyan;')
    [void]$sb.AppendLine('                case ConsoleColor.DarkBlue: return ColorTranslator.FromHtml("#000080");')
    [void]$sb.AppendLine('                case ConsoleColor.DarkGray: return ColorTranslator.FromHtml("#808080");')
    [void]$sb.AppendLine('                case ConsoleColor.DarkGreen: return ColorTranslator.FromHtml("#008000");')
    [void]$sb.AppendLine('                case ConsoleColor.DarkCyan: return ColorTranslator.FromHtml("#008080");')
    [void]$sb.AppendLine('                case ConsoleColor.DarkMagenta: return ColorTranslator.FromHtml("#800080");')
    [void]$sb.AppendLine('                case ConsoleColor.DarkRed: return ColorTranslator.FromHtml("#800000");')
    [void]$sb.AppendLine('                case ConsoleColor.DarkYellow: return ColorTranslator.FromHtml("#808000");')
    [void]$sb.AppendLine('                case ConsoleColor.Gray: return ColorTranslator.FromHtml("#C0C0C0");')
    [void]$sb.AppendLine('                case ConsoleColor.Green: return ColorTranslator.FromHtml("#00FF00");')
    [void]$sb.AppendLine('                case ConsoleColor.Magenta: return Color.Magenta;')
    [void]$sb.AppendLine('                case ConsoleColor.Red: return Color.Red;')
    [void]$sb.AppendLine('                case ConsoleColor.White: return Color.White;')
    [void]$sb.AppendLine('                default: return Color.Yellow;')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        private void InitializeComponent()')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            this.SuspendLayout();')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            this.Text = "Progress";')
    [void]$sb.AppendLine('            this.Height = 160;')
    [void]$sb.AppendLine('            this.Width = 800;')
    [void]$sb.AppendLine('            this.BackColor = Color.White;')
    [void]$sb.AppendLine('            this.FormBorderStyle = FormBorderStyle.FixedSingle;')
    [void]$sb.AppendLine('            try')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                this.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            catch')
    [void]$sb.AppendLine('            { }')
    [void]$sb.AppendLine('            this.MinimizeBox = false;')
    [void]$sb.AppendLine('            this.MaximizeBox = false;')
    [void]$sb.AppendLine('            this.StartPosition = FormStartPosition.CenterScreen;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Create Label')
    [void]$sb.AppendLine('            objLblActivity = new Label();')
    [void]$sb.AppendLine('            objLblActivity.Left = 5;')
    [void]$sb.AppendLine('            objLblActivity.Top = 10;')
    [void]$sb.AppendLine('            objLblActivity.Width = 800 - 20;')
    [void]$sb.AppendLine('            objLblActivity.Height = 16;')
    [void]$sb.AppendLine('            objLblActivity.Font = new Font(objLblActivity.Font, FontStyle.Bold);')
    [void]$sb.AppendLine('            objLblActivity.Text = "";')
    [void]$sb.AppendLine('            // Add Label to Form')
    [void]$sb.AppendLine('            this.Controls.Add(objLblActivity);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Create Label')
    [void]$sb.AppendLine('            objLblStatus = new Label();')
    [void]$sb.AppendLine('            objLblStatus.Left = 25;')
    [void]$sb.AppendLine('            objLblStatus.Top = 26;')
    [void]$sb.AppendLine('            objLblStatus.Width = 800 - 40;')
    [void]$sb.AppendLine('            objLblStatus.Height = 16;')
    [void]$sb.AppendLine('            objLblStatus.Text = "";')
    [void]$sb.AppendLine('            // Add Label to Form')
    [void]$sb.AppendLine('            this.Controls.Add(objLblStatus);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Create ProgressBar')
    [void]$sb.AppendLine('            objProgressBar = new ProgressBar();')
    [void]$sb.AppendLine('            objProgressBar.Value = 0;')
    [void]$sb.AppendLine('            objProgressBar.Style = ProgressBarStyle.Continuous;')
    [void]$sb.AppendLine('            objProgressBar.ForeColor = DrawingColor(ProgressBarColor);')
    [void]$sb.AppendLine('            objProgressBar.Size = new System.Drawing.Size(800 - 60, 20);')
    [void]$sb.AppendLine('            objProgressBar.Left = 25;')
    [void]$sb.AppendLine('            objProgressBar.Top = 55;')
    [void]$sb.AppendLine('            // Add ProgressBar to Form')
    [void]$sb.AppendLine('            this.Controls.Add(objProgressBar);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Create Label')
    [void]$sb.AppendLine('            objLblRemainingTime = new Label();')
    [void]$sb.AppendLine('            objLblRemainingTime.Left = 5;')
    [void]$sb.AppendLine('            objLblRemainingTime.Top = 85;')
    [void]$sb.AppendLine('            objLblRemainingTime.Width = 800 - 20;')
    [void]$sb.AppendLine('            objLblRemainingTime.Height = 16;')
    [void]$sb.AppendLine('            objLblRemainingTime.Text = "";')
    [void]$sb.AppendLine('            // Add Label to Form')
    [void]$sb.AppendLine('            this.Controls.Add(objLblRemainingTime);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Create Label')
    [void]$sb.AppendLine('            objLblOperation = new Label();')
    [void]$sb.AppendLine('            objLblOperation.Left = 25;')
    [void]$sb.AppendLine('            objLblOperation.Top = 101;')
    [void]$sb.AppendLine('            objLblOperation.Width = 800 - 40;')
    [void]$sb.AppendLine('            objLblOperation.Height = 16;')
    [void]$sb.AppendLine('            objLblOperation.Text = "";')
    [void]$sb.AppendLine('            // Add Label to Form')
    [void]$sb.AppendLine('            this.Controls.Add(objLblOperation);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            this.ResumeLayout();')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public ProgressForm()')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            InitializeComponent();')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public ProgressForm(ConsoleColor BarColor)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            ProgressBarColor = BarColor;')
    [void]$sb.AppendLine('            InitializeComponent();')
    [void]$sb.AppendLine('        }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public void Update(ProgressRecord objRecord)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            if (objRecord == null)')
    [void]$sb.AppendLine('                return;')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (objRecord.RecordType == ProgressRecordType.Completed)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                this.Close();')
    [void]$sb.AppendLine('                return;')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(objRecord.Activity))')
    [void]$sb.AppendLine('                objLblActivity.Text = objRecord.Activity;')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                objLblActivity.Text = "";')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(objRecord.StatusDescription))')
    [void]$sb.AppendLine('                objLblStatus.Text = objRecord.StatusDescription;')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                objLblStatus.Text = "";')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if ((objRecord.PercentComplete >= 0) && (objRecord.PercentComplete <= 100))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                objProgressBar.Value = objRecord.PercentComplete;')
    [void]$sb.AppendLine('                objProgressBar.Visible = true;')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                if (objRecord.PercentComplete > 100)')
    [void]$sb.AppendLine('                {')
    [void]$sb.AppendLine('                    objProgressBar.Value = 0;')
    [void]$sb.AppendLine('                    objProgressBar.Visible = true;')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('                else')
    [void]$sb.AppendLine('                    objProgressBar.Visible = false;')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (objRecord.SecondsRemaining >= 0)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                System.TimeSpan objTimeSpan = new System.TimeSpan(0, 0, objRecord.SecondsRemaining);')
    [void]$sb.AppendLine('                objLblRemainingTime.Text = "Remaining time: " + string.Format("{0:00}:{1:00}:{2:00}", (int)objTimeSpan.TotalHours, objTimeSpan.Minutes, objTimeSpan.Seconds);')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                objLblRemainingTime.Text = "";')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(objRecord.CurrentOperation))')
    [void]$sb.AppendLine('                objLblOperation.Text = objRecord.CurrentOperation;')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                objLblOperation.Text = "";')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            this.Refresh();')
    [void]$sb.AppendLine('            Application.DoEvents();')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('    }')
}

#endregion

#region Redirects

[void]$sb.AppendLine()
[void]$sb.AppendLine('    // define IsInputRedirected(), IsOutputRedirected() and IsErrorRedirected() here since they were introduced first with .Net 4.5')
[void]$sb.AppendLine('    public class ConsoleInfo')
[void]$sb.AppendLine('    {')
[void]$sb.AppendLine('        private enum FileType : uint')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            FILE_TYPE_UNKNOWN = 0x0000,')
[void]$sb.AppendLine('            FILE_TYPE_DISK = 0x0001,')
[void]$sb.AppendLine('            FILE_TYPE_CHAR = 0x0002,')
[void]$sb.AppendLine('            FILE_TYPE_PIPE = 0x0003,')
[void]$sb.AppendLine('            FILE_TYPE_REMOTE = 0x8000')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        private enum STDHandle : uint')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            STD_INPUT_HANDLE = unchecked((uint)-10),')
[void]$sb.AppendLine('            STD_OUTPUT_HANDLE = unchecked((uint)-11),')
[void]$sb.AppendLine('            STD_ERROR_HANDLE = unchecked((uint)-12)')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        [DllImport("kernel32.dll")]')
[void]$sb.AppendLine('        static private extern UIntPtr GetStdHandle(STDHandle stdHandle);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        [DllImport("kernel32.dll")]')
[void]$sb.AppendLine('        static private extern FileType GetFileType(UIntPtr hFile);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        static public bool IsInputRedirected()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            UIntPtr hInput = GetStdHandle(STDHandle.STD_INPUT_HANDLE);')
[void]$sb.AppendLine('            FileType fileType = (FileType)GetFileType(hInput);')
[void]$sb.AppendLine('            if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))')
[void]$sb.AppendLine('                return false;')
[void]$sb.AppendLine('            return true;')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        static public bool IsOutputRedirected()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            UIntPtr hOutput = GetStdHandle(STDHandle.STD_OUTPUT_HANDLE);')
[void]$sb.AppendLine('            FileType fileType = (FileType)GetFileType(hOutput);')
[void]$sb.AppendLine('            if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))')
[void]$sb.AppendLine('                return false;')
[void]$sb.AppendLine('            return true;')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        static public bool IsErrorRedirected()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            UIntPtr hError = GetStdHandle(STDHandle.STD_ERROR_HANDLE);')
[void]$sb.AppendLine('            FileType fileType = (FileType)GetFileType(hError);')
[void]$sb.AppendLine('            if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))')
[void]$sb.AppendLine('                return false;')
[void]$sb.AppendLine('            return true;')
[void]$sb.AppendLine('        }')
[void]$sb.AppendLine('    }')

#endregion

#region PS2EXE Host User Interface

[void]$sb.AppendLine()
[void]$sb.AppendLine('    internal class PS2EXEHostUI : PSHostUserInterface')
[void]$sb.AppendLine('    {')
[void]$sb.AppendLine('        private PS2EXEHostRawUI rawUI = null;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public ConsoleColor ErrorForegroundColor = ConsoleColor.Red;')
[void]$sb.AppendLine('        public ConsoleColor ErrorBackgroundColor = ConsoleColor.Black;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public ConsoleColor WarningForegroundColor = ConsoleColor.Yellow;')
[void]$sb.AppendLine('        public ConsoleColor WarningBackgroundColor = ConsoleColor.Black;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public ConsoleColor DebugForegroundColor = ConsoleColor.Yellow;')
[void]$sb.AppendLine('        public ConsoleColor DebugBackgroundColor = ConsoleColor.Black;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public ConsoleColor VerboseForegroundColor = ConsoleColor.Yellow;')
[void]$sb.AppendLine('        public ConsoleColor VerboseBackgroundColor = ConsoleColor.Black;')

if (-not $NoConsole) {
    [void]$sb.AppendLine('        public ConsoleColor ProgressForegroundColor = ConsoleColor.Yellow;')
}
else {
    [void]$sb.AppendLine('        public ConsoleColor ProgressForegroundColor = ConsoleColor.DarkCyan;')
}

[void]$sb.AppendLine('        public ConsoleColor ProgressBackgroundColor = ConsoleColor.DarkCyan;')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public PS2EXEHostUI() : base()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            rawUI = new PS2EXEHostRawUI();')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            rawUI.ForegroundColor = Console.ForegroundColor;')
    [void]$sb.AppendLine('            rawUI.BackgroundColor = Console.BackgroundColor;')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override Dictionary<string, PSObject> Prompt(string caption, string message, System.Collections.ObjectModel.Collection<FieldDescription> descriptions)')
[void]$sb.AppendLine('        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(caption)) WriteLine(caption);')
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(message)) WriteLine(message);')
}
else {
    [void]$sb.AppendLine('            if ((!string.IsNullOrEmpty(caption)) || (!string.IsNullOrEmpty(message)))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                string sTitel = System.AppDomain.CurrentDomain.FriendlyName, sMeldung = "";')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('                if (!string.IsNullOrEmpty(caption)) sTitel = caption;')
    [void]$sb.AppendLine('                if (!string.IsNullOrEmpty(message)) sMeldung = message;')
    [void]$sb.AppendLine('                MessageBox.Show(sMeldung, sTitel);')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            // Titel und Labeltext für Inputbox zurücksetzen')
    [void]$sb.AppendLine('            ibcaption = "";')
    [void]$sb.AppendLine('            ibmessage = "";')
}

[void]$sb.AppendLine('            Dictionary<string, PSObject> ret = new Dictionary<string, PSObject>();')
[void]$sb.AppendLine('            foreach (FieldDescription cd in descriptions)')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                Type t = null;')
[void]$sb.AppendLine('                if (string.IsNullOrEmpty(cd.ParameterAssemblyFullName))')
[void]$sb.AppendLine('                    t = typeof(string);')
[void]$sb.AppendLine('                else')
[void]$sb.AppendLine('                    t = Type.GetType(cd.ParameterAssemblyFullName);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                if (t.IsArray)')
[void]$sb.AppendLine('                {')
[void]$sb.AppendLine('                    Type elementType = t.GetElementType();')
[void]$sb.AppendLine('                    Type genericListType = Type.GetType("System.Collections.Generic.List" + ((char)0x60).ToString() + "1");')
[void]$sb.AppendLine('                    genericListType = genericListType.MakeGenericType(new Type[] { elementType });')
[void]$sb.AppendLine('                    ConstructorInfo constructor = genericListType.GetConstructor(BindingFlags.CreateInstance | BindingFlags.Instance | BindingFlags.Public, null, Type.EmptyTypes, null);')
[void]$sb.AppendLine('                    object resultList = constructor.Invoke(null);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                    int index = 0;')
[void]$sb.AppendLine('                    string data = "";')
[void]$sb.AppendLine('                    do')
[void]$sb.AppendLine('                    {')
[void]$sb.AppendLine('                        try')
[void]$sb.AppendLine('                        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                            if (!string.IsNullOrEmpty(cd.Name)) Write(string.Format("{0}[{1}]: ", cd.Name, index));')
}
else {
    [void]$sb.AppendLine('                            if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}[{1}]: ", cd.Name, index);')
}

[void]$sb.AppendLine('                            data = ReadLine();')
[void]$sb.AppendLine('                            if (string.IsNullOrEmpty(data))')
[void]$sb.AppendLine('                                break;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                            object o = System.Convert.ChangeType(data, elementType);')
[void]$sb.AppendLine('                            genericListType.InvokeMember("Add", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, new object[] { o });')
[void]$sb.AppendLine('                        }')
[void]$sb.AppendLine('                        catch (Exception e)')
[void]$sb.AppendLine('                        {')
[void]$sb.AppendLine('                            throw e;')
[void]$sb.AppendLine('                        }')
[void]$sb.AppendLine('                        index++;')
[void]$sb.AppendLine('                    } while (true);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                    System.Array retArray = (System.Array)genericListType.InvokeMember("ToArray", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, null);')
[void]$sb.AppendLine('                    ret.Add(cd.Name, new PSObject(retArray));')
[void]$sb.AppendLine('                }')
[void]$sb.AppendLine('                else')
[void]$sb.AppendLine('                {')
[void]$sb.AppendLine('                    object o = null;')
[void]$sb.AppendLine('                    string l = null;')
[void]$sb.AppendLine('                    try')
[void]$sb.AppendLine('                    {')
[void]$sb.AppendLine('                        if (t != typeof(System.Security.SecureString))')
[void]$sb.AppendLine('                        {')
[void]$sb.AppendLine('                            if (t != typeof(System.Management.Automation.PSCredential))')
[void]$sb.AppendLine('                            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                                if (!string.IsNullOrEmpty(cd.Name)) Write(cd.Name);')
    [void]$sb.AppendLine('                                if (!string.IsNullOrEmpty(cd.HelpMessage)) Write(" (Type !? for help.)");')
    [void]$sb.AppendLine('                                if ((!string.IsNullOrEmpty(cd.Name)) || (!string.IsNullOrEmpty(cd.HelpMessage))) Write(": ");')
}
else {
    [void]$sb.AppendLine('                                if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}: ", cd.Name);')
    [void]$sb.AppendLine('                                if (!string.IsNullOrEmpty(cd.HelpMessage)) ibmessage += "\n(Type !? for help.)";')
}

[void]$sb.AppendLine('                                do')
[void]$sb.AppendLine('                                {')
[void]$sb.AppendLine('                                    l = ReadLine();')
[void]$sb.AppendLine('                                    if (l == "!?")')
[void]$sb.AppendLine('                                        WriteLine(cd.HelpMessage);')
[void]$sb.AppendLine('                                    else')
[void]$sb.AppendLine('                                    {')
[void]$sb.AppendLine('                                        if (string.IsNullOrEmpty(l)) o = cd.DefaultValue;')
[void]$sb.AppendLine('                                        if (o == null)')
[void]$sb.AppendLine('                                        {')
[void]$sb.AppendLine('                                            try')
[void]$sb.AppendLine('                                            {')
[void]$sb.AppendLine('                                                o = System.Convert.ChangeType(l, t);')
[void]$sb.AppendLine('                                            }')
[void]$sb.AppendLine('                                            catch')
[void]$sb.AppendLine('                                            {')
[void]$sb.AppendLine('                                                Write("Wrong format, please repeat input: ");')
[void]$sb.AppendLine('                                                l = "!?";')
[void]$sb.AppendLine('                                            }')
[void]$sb.AppendLine('                                        }')
[void]$sb.AppendLine('                                    }')
[void]$sb.AppendLine('                                } while (l == "!?");')
[void]$sb.AppendLine('                            }')
[void]$sb.AppendLine('                            else')
[void]$sb.AppendLine('                            {')
[void]$sb.AppendLine('                                PSCredential pscred = PromptForCredential("", "", "", "");')
[void]$sb.AppendLine('                                o = pscred;')
[void]$sb.AppendLine('                            }')
[void]$sb.AppendLine('                        }')
[void]$sb.AppendLine('                        else')
[void]$sb.AppendLine('                        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                            if (!string.IsNullOrEmpty(cd.Name)) Write(string.Format("{0}: ", cd.Name));')
}
else {
    [void]$sb.AppendLine('                            if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}: ", cd.Name);')
}

[void]$sb.AppendLine()
[void]$sb.AppendLine('                            SecureString pwd = null;')
[void]$sb.AppendLine('                            pwd = ReadLineAsSecureString();')
[void]$sb.AppendLine('                            o = pwd;')
[void]$sb.AppendLine('                        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        ret.Add(cd.Name, new PSObject(o));')
[void]$sb.AppendLine('                    }')
[void]$sb.AppendLine('                    catch (Exception e)')
[void]$sb.AppendLine('                    {')
[void]$sb.AppendLine('                        throw e;')
[void]$sb.AppendLine('                    }')
[void]$sb.AppendLine('                }')
[void]$sb.AppendLine('            }')

if ($NoConsole) {
    [void]$sb.AppendLine('            // Titel und Labeltext für Inputbox zurücksetzen')
    [void]$sb.AppendLine('            ibcaption = "";')
    [void]$sb.AppendLine('            ibmessage = "";')
}

[void]$sb.AppendLine('            return ret;')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override int PromptForChoice(string caption, string message, System.Collections.ObjectModel.Collection<ChoiceDescription> choices, int defaultChoice)')
[void]$sb.AppendLine('        {')

if ($NoConsole) {
    [void]$sb.AppendLine('            int iReturn = ChoiceBox.Show(choices, defaultChoice, caption, message);')
    [void]$sb.AppendLine('            if (iReturn == -1) { iReturn = defaultChoice; }')
    [void]$sb.AppendLine('            return iReturn;')
}
else {
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(caption))')
    [void]$sb.AppendLine('                WriteLine(caption);')
    [void]$sb.AppendLine('            WriteLine(message);')
    [void]$sb.AppendLine('            int idx = 0;')
    [void]$sb.AppendLine('            SortedList<string, int> res = new SortedList<string, int>();')
    [void]$sb.AppendLine('            foreach (ChoiceDescription cd in choices)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                string lkey = cd.Label.Substring(0, 1), ltext = cd.Label;')
    [void]$sb.AppendLine('                int pos = cd.Label.IndexOf(''&'');')
    [void]$sb.AppendLine('                if (pos > -1)')
    [void]$sb.AppendLine('                {')
    [void]$sb.AppendLine('                    lkey = cd.Label.Substring(pos + 1, 1).ToUpper();')
    [void]$sb.AppendLine('                    if (pos > 0)')
    [void]$sb.AppendLine('                        ltext = cd.Label.Substring(0, pos) + cd.Label.Substring(pos + 1);')
    [void]$sb.AppendLine('                    else')
    [void]$sb.AppendLine('                        ltext = cd.Label.Substring(1);')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('                res.Add(lkey.ToLower(), idx);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('                if (idx > 0) Write("  ");')
    [void]$sb.AppendLine('                if (idx == defaultChoice)')
    [void]$sb.AppendLine('                {')
    [void]$sb.AppendLine('                    Write(ConsoleColor.Yellow, Console.BackgroundColor, string.Format("[{0}] {1}", lkey, ltext));')
    [void]$sb.AppendLine('                    if (!string.IsNullOrEmpty(cd.HelpMessage))')
    [void]$sb.AppendLine('                        Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format(" ({0})", cd.HelpMessage));')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('                else')
    [void]$sb.AppendLine('                {')
    [void]$sb.AppendLine('                    Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format("[{0}] {1}", lkey, ltext));')
    [void]$sb.AppendLine('                    if (!string.IsNullOrEmpty(cd.HelpMessage))')
    [void]$sb.AppendLine('                        Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format(" ({0})", cd.HelpMessage));')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('                idx++;')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            Write(": ");')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            try')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                while (true)')
    [void]$sb.AppendLine('                {')
    [void]$sb.AppendLine('                    string s = Console.ReadLine().ToLower();')
    [void]$sb.AppendLine('                    if (res.ContainsKey(s))')
    [void]$sb.AppendLine('                        return res[s];')
    [void]$sb.AppendLine('                    if (string.IsNullOrEmpty(s))')
    [void]$sb.AppendLine('                        return defaultChoice;')
    [void]$sb.AppendLine('                }')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            catch { }')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            return defaultChoice;')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)')
[void]$sb.AppendLine('        {')

if ((-not $NoConsole) -and (-not $CredentialGUI)) {
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(caption)) WriteLine(caption);')
    [void]$sb.AppendLine('            WriteLine(message);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            string un;')
    [void]$sb.AppendLine('            if ((string.IsNullOrEmpty(userName)) || ((options & PSCredentialUIOptions.ReadOnlyUserName) == 0))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                Write("User name: ");')
    [void]$sb.AppendLine('                un = ReadLine();')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                Write("User name: ");')
    [void]$sb.AppendLine('                if (!string.IsNullOrEmpty(targetName)) Write(targetName + "\\");')
    [void]$sb.AppendLine('                WriteLine(userName);')
    [void]$sb.AppendLine('                un = userName;')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            SecureString pwd = null;')
    [void]$sb.AppendLine('            Write("Password: ");')
    [void]$sb.AppendLine('            pwd = ReadLineAsSecureString();')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(un)) un = "<NOUSER>";')
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(targetName))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                if (un.IndexOf(''\\'') < 0)')
    [void]$sb.AppendLine('                    un = targetName + "\\" + un;')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            PSCredential c2 = new PSCredential(un, pwd);')
    [void]$sb.AppendLine('            return c2;')
}
else {
    [void]$sb.AppendLine('            ik.PowerShell.CredentialForm.UserPwd cred = CredentialForm.PromptForPassword(caption, message, targetName, userName, allowedCredentialTypes, options);')
    [void]$sb.AppendLine('            if (cred != null)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                System.Security.SecureString x = new System.Security.SecureString();')
    [void]$sb.AppendLine('                foreach (char c in cred.Password.ToCharArray())')
    [void]$sb.AppendLine('                    x.AppendChar(c);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('                return new PSCredential(cred.User, x);')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            return null;')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)')
[void]$sb.AppendLine('        {')

if ((-not $NoConsole) -and (-not $CredentialGUI)) {
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(caption)) WriteLine(caption);')
    [void]$sb.AppendLine('            WriteLine(message);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            string un;')
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(userName))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                Write("User name: ");')
    [void]$sb.AppendLine('                un = ReadLine();')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                Write("User name: ");')
    [void]$sb.AppendLine('                if (!string.IsNullOrEmpty(targetName)) Write(targetName + "\\");')
    [void]$sb.AppendLine('                WriteLine(userName);')
    [void]$sb.AppendLine('                un = userName;')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            SecureString pwd = null;')
    [void]$sb.AppendLine('            Write("Password: ");')
    [void]$sb.AppendLine('            pwd = ReadLineAsSecureString();')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (string.IsNullOrEmpty(un)) un = "<NOUSER>";')
    [void]$sb.AppendLine('            if (!string.IsNullOrEmpty(targetName))')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                if (un.IndexOf(''\\'') < 0)')
    [void]$sb.AppendLine('                    un = targetName + "\\" + un;')
    [void]$sb.AppendLine('            }')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            PSCredential c2 = new PSCredential(un, pwd);')
    [void]$sb.AppendLine('            return c2;')
}
else {
    [void]$sb.AppendLine('            ik.PowerShell.CredentialForm.UserPwd cred = CredentialForm.PromptForPassword(caption, message, targetName, userName, PSCredentialTypes.Default, PSCredentialUIOptions.Default);')
    [void]$sb.AppendLine('            if (cred != null)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                System.Security.SecureString x = new System.Security.SecureString();')
    [void]$sb.AppendLine('                foreach (char c in cred.Password.ToCharArray())')
    [void]$sb.AppendLine('                    x.AppendChar(c);')

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('                return new PSCredential(cred.User, x);')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            return null;')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override PSHostRawUserInterface RawUI')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                return rawUI;')
[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')
[void]$sb.AppendLine()

if ($NoConsole) {
    [void]$sb.AppendLine('        private string ibcaption;')
    [void]$sb.AppendLine('        private string ibmessage;')
}

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override string ReadLine()')
[void]$sb.AppendLine('        {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            return Console.ReadLine();')
}
else {
    [void]$sb.AppendLine('            string sWert = "";')
    [void]$sb.AppendLine('            if (InputBox.Show(ibcaption, ibmessage, ref sWert) == DialogResult.OK)')
    [void]$sb.AppendLine('                return sWert;')
    [void]$sb.AppendLine('            else')
    [void]$sb.AppendLine('                return "";')
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        private System.Security.SecureString getPassword()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            System.Security.SecureString pwd = new System.Security.SecureString();')
[void]$sb.AppendLine('            while (true)')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                ConsoleKeyInfo i = Console.ReadKey(true);')
[void]$sb.AppendLine('                if (i.Key == ConsoleKey.Enter)')
[void]$sb.AppendLine('                {')
[void]$sb.AppendLine('                    Console.WriteLine();')
[void]$sb.AppendLine('                    break;')
[void]$sb.AppendLine('                }')
[void]$sb.AppendLine('                else if (i.Key == ConsoleKey.Backspace)')
[void]$sb.AppendLine('                {')
[void]$sb.AppendLine('                    if (pwd.Length > 0)')
[void]$sb.AppendLine('                    {')
[void]$sb.AppendLine('                        pwd.RemoveAt(pwd.Length - 1);')
[void]$sb.AppendLine('                        Console.Write("\b \b");')
[void]$sb.AppendLine('                    }')
[void]$sb.AppendLine('                }')
[void]$sb.AppendLine('                else if (i.KeyChar != ''\u0000'')')
[void]$sb.AppendLine('                {')
[void]$sb.AppendLine('                    pwd.AppendChar(i.KeyChar);')
[void]$sb.AppendLine('                    Console.Write("*");')
[void]$sb.AppendLine('                }')
[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            return pwd;')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override System.Security.SecureString ReadLineAsSecureString()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            System.Security.SecureString secstr = new System.Security.SecureString();')

if (-not $NoConsole) {
    [void]$sb.AppendLine('            secstr = getPassword();')
}
else {
    [void]$sb.AppendLine('            string sWert = "";')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('            if (InputBox.Show(ibcaption, ibmessage, ref sWert, true) == DialogResult.OK)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                foreach (char ch in sWert)')
    [void]$sb.AppendLine('                    secstr.AppendChar(ch);')
    [void]$sb.AppendLine('            }')
}

[void]$sb.AppendLine('            return secstr;')
[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        // called by Write-Host')
[void]$sb.AppendLine('        public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)')
[void]$sb.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;')
        [void]$sb.AppendLine('            Console.ForegroundColor = foregroundColor;')
        [void]$sb.AppendLine('            Console.BackgroundColor = backgroundColor;')
        [void]$sb.AppendLine('            Console.Write(value);')
        [void]$sb.AppendLine('            Console.ForegroundColor = fgc;')
        [void]$sb.AppendLine('            Console.BackgroundColor = bgc;')
    }
    else {
        [void]$sb.AppendLine('            if ((!string.IsNullOrEmpty(value)) && (value != "\n"))')
        [void]$sb.AppendLine('                MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void Write(string value)')
[void]$sb.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            Console.Write(value);')
    }
    else {
        [void]$sb.AppendLine('            if ((!string.IsNullOrEmpty(value)) && (value != "\n"))')
        [void]$sb.AppendLine('                MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        // called by Write-Debug')
[void]$sb.AppendLine('        public override void WriteDebugLine(string message)')
[void]$sb.AppendLine('        {')

if (-not $NoError) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            WriteLineInternal(DebugForegroundColor, DebugBackgroundColor, string.Format("DEBUG: {0}", message));')
    }
    else {
        [void]$sb.AppendLine('            MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Information);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        // called by Write-Error')
[void]$sb.AppendLine('        public override void WriteErrorLine(string value)')
[void]$sb.AppendLine('        {')

if (-not $NoError) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            if (ConsoleInfo.IsErrorRedirected())')
        [void]$sb.AppendLine('                Console.Error.WriteLine(string.Format("ERROR: {0}", value));')
        [void]$sb.AppendLine('            else')
        [void]$sb.AppendLine('                WriteLineInternal(ErrorForegroundColor, ErrorBackgroundColor, string.Format("ERROR: {0}", value));')
    }
    else {
        [void]$sb.AppendLine('            MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void WriteLine()')
[void]$sb.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            Console.WriteLine();')
    }
    else {
        [void]$sb.AppendLine('            MessageBox.Show("", System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void WriteLine(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)')
[void]$sb.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;')
        [void]$sb.AppendLine('            Console.ForegroundColor = foregroundColor;')
        [void]$sb.AppendLine('            Console.BackgroundColor = backgroundColor;')
        [void]$sb.AppendLine('            Console.WriteLine(value);')
        [void]$sb.AppendLine('            Console.ForegroundColor = fgc;')
        [void]$sb.AppendLine('            Console.BackgroundColor = bgc;')
    } else {
        [void]$sb.AppendLine('            if ((!string.IsNullOrEmpty(value)) && (value != "\n"))')
        [void]$sb.AppendLine('                MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$sb.AppendLine('        }')


if ((-not $NoError) -and (-not $NoConsole)) {
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        private void WriteLineInternal(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)')
    [void]$sb.AppendLine('        {')
    [void]$sb.AppendLine('            ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;')
    [void]$sb.AppendLine('            Console.ForegroundColor = foregroundColor;')
    [void]$sb.AppendLine('            Console.BackgroundColor = backgroundColor;')
    [void]$sb.AppendLine('            Console.WriteLine(value);')
    [void]$sb.AppendLine('            Console.ForegroundColor = fgc;')
    [void]$sb.AppendLine('            Console.BackgroundColor = bgc;')
    [void]$sb.AppendLine('        }')
}


[void]$sb.AppendLine()
[void]$sb.AppendLine('        // called by Write-Output')
[void]$sb.AppendLine('        public override void WriteLine(string value)')
[void]$sb.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            Console.WriteLine(value);')
    } else {
        [void]$sb.AppendLine('            if ((!string.IsNullOrEmpty(value)) && (value != "\n"))')
        [void]$sb.AppendLine('                MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$sb.AppendLine('        }')


if ($NoConsole) {
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('        public ProgressForm pf = null;')
}


[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void WriteProgress(long sourceId, ProgressRecord record)')
[void]$sb.AppendLine('        {')

if ($NoConsole) {
    [void]$sb.AppendLine('            if (pf == null)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                pf = new ProgressForm(ProgressForegroundColor);')
    [void]$sb.AppendLine('                pf.Show();')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            pf.Update(record);')
    [void]$sb.AppendLine('            if (record.RecordType == ProgressRecordType.Completed)')
    [void]$sb.AppendLine('            {')
    [void]$sb.AppendLine('                pf = null;')
    [void]$sb.AppendLine('            }')
}

[void]$sb.AppendLine('        }')



[void]$sb.AppendLine()
[void]$sb.AppendLine('        // called by Write-Verbose')
[void]$sb.AppendLine('        public override void WriteVerboseLine(string message)')
[void]$sb.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            WriteLine(VerboseForegroundColor, VerboseBackgroundColor, string.Format("VERBOSE: {0}", message));')
    }
    else {
        [void]$sb.AppendLine('            MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Information);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('        // called by Write-Warning')
[void]$sb.AppendLine('        public override void WriteWarningLine(string message)')
[void]$sb.AppendLine('        {')

if (-not $NoError) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('            WriteLineInternal(WarningForegroundColor, WarningBackgroundColor, string.Format("WARNING: {0}", message));')
    }
    else {
        [void]$sb.AppendLine('            MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Warning);')
    }
}

[void]$sb.AppendLine('        }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('    }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('    internal class PS2EXEHost : PSHost')
[void]$sb.AppendLine('    {')
[void]$sb.AppendLine('        private PS2EXEApp parent;')
[void]$sb.AppendLine('        private PS2EXEHostUI ui = null;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        private CultureInfo originalCultureInfo = System.Threading.Thread.CurrentThread.CurrentCulture;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        private CultureInfo originalUICultureInfo = System.Threading.Thread.CurrentThread.CurrentUICulture;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        private Guid myId = Guid.NewGuid();')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public PS2EXEHost(PS2EXEApp app, PS2EXEHostUI ui)')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            this.parent = app;')
[void]$sb.AppendLine('            this.ui = ui;')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public class ConsoleColorProxy')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            private PS2EXEHostUI _ui;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColorProxy(PS2EXEHostUI ui)')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                if (ui == null) throw new ArgumentNullException("ui");')
[void]$sb.AppendLine('                _ui = ui;')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor ErrorForegroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.ErrorForegroundColor; }')
[void]$sb.AppendLine('                set { _ui.ErrorForegroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor ErrorBackgroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.ErrorBackgroundColor; }')
[void]$sb.AppendLine('                set { _ui.ErrorBackgroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor WarningForegroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.WarningForegroundColor; }')
[void]$sb.AppendLine('                set { _ui.WarningForegroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor WarningBackgroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.WarningBackgroundColor; }')
[void]$sb.AppendLine('                set { _ui.WarningBackgroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor DebugForegroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.DebugForegroundColor; }')
[void]$sb.AppendLine('                set { _ui.DebugForegroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor DebugBackgroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.DebugBackgroundColor; }')
[void]$sb.AppendLine('                set { _ui.DebugBackgroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor VerboseForegroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.VerboseForegroundColor; }')
[void]$sb.AppendLine('                set { _ui.VerboseForegroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor VerboseBackgroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.VerboseBackgroundColor; }')
[void]$sb.AppendLine('                set { _ui.VerboseBackgroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor ProgressForegroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.ProgressForegroundColor; }')
[void]$sb.AppendLine('                set { _ui.ProgressForegroundColor = value; }')
[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            public ConsoleColor ProgressBackgroundColor')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                get { return _ui.ProgressBackgroundColor; }')
[void]$sb.AppendLine('                set { _ui.ProgressBackgroundColor = value; }')
[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override PSObject PrivateData')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                if (ui == null) return null;')
[void]$sb.AppendLine('                return _consoleColorProxy ?? (_consoleColorProxy = PSObject.AsPSObject(new ConsoleColorProxy(ui)));')
[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        private PSObject _consoleColorProxy;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override System.Globalization.CultureInfo CurrentCulture')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get { return this.originalCultureInfo; }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override System.Globalization.CultureInfo CurrentUICulture')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get { return this.originalUICultureInfo; }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override Guid InstanceId')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get { return this.myId; }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override string Name')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get { return "PS2EXE_Host"; }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override PSHostUserInterface UI')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get { return ui; }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override Version Version')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get { return new Version(0, 5, 0, 19); }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void EnterNestedPrompt()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void ExitNestedPrompt()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void NotifyBeginApplication()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            return;')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void NotifyEndApplication()')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            return;')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public override void SetShouldExit(int exitCode)')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            this.parent.ShouldExit = true;')
[void]$sb.AppendLine('            this.parent.ExitCode = exitCode;')
[void]$sb.AppendLine('        }')
[void]$sb.AppendLine('    }')

#endregion

#region PS2EXE Application

[void]$sb.AppendLine()
[void]$sb.AppendLine('    internal interface PS2EXEApp')
[void]$sb.AppendLine('    {')
[void]$sb.AppendLine('        bool ShouldExit { get; set; }')
[void]$sb.AppendLine('        int ExitCode { get; set; }')
[void]$sb.AppendLine('    }')


[void]$sb.AppendLine()
[void]$sb.AppendLine('    internal class PS2EXE : PS2EXEApp')
[void]$sb.AppendLine('    {')
[void]$sb.AppendLine('        private bool shouldExit;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        private int exitCode;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public bool ShouldExit')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get { return this.shouldExit; }')
[void]$sb.AppendLine('            set { this.shouldExit = value; }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        public int ExitCode')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            get { return this.exitCode; }')
[void]$sb.AppendLine('            set { this.exitCode = value; }')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()

if ($STA) { [void]$sb.AppendLine('        [STAThread]') }
if ($MTA) { [void]$sb.AppendLine('        [MTAThread]') }

[void]$sb.AppendLine('        private static int Main(string[] args)')
[void]$sb.AppendLine('        {')

if (-not [string]::IsNullOrEmpty($culture.ToString())) {
    [void]$sb.AppendFormat('            {0}', $culture.ToString()).AppendLine()
}

[void]$sb.AppendLine()
[void]$sb.AppendLine('            PS2EXE me = new PS2EXE();')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            bool paramWait = false;')
[void]$sb.AppendLine('            string extractFN = string.Empty;')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            PS2EXEHostUI ui = new PS2EXEHostUI();')
[void]$sb.AppendLine('            PS2EXEHost host = new PS2EXEHost(me, ui);')
[void]$sb.AppendLine('            System.Threading.ManualResetEvent mre = new System.Threading.ManualResetEvent(false);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            AppDomain.CurrentDomain.UnhandledException += new UnhandledExceptionEventHandler(CurrentDomain_UnhandledException);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            try')
[void]$sb.AppendLine('            {')
[void]$sb.AppendLine('                using (Runspace myRunSpace = RunspaceFactory.CreateRunspace(host))')
[void]$sb.AppendLine('                {')

if ($STA) { [void]$sb.AppendLine('                    myRunSpace.ApartmentState = System.Threading.ApartmentState.STA;') }
if ($MTA) { [void]$sb.AppendLine('                    myRunSpace.ApartmentState = System.Threading.ApartmentState.MTA;') }

[void]$sb.AppendLine('                    myRunSpace.Open();')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                    using (System.Management.Automation.PowerShell powershell = System.Management.Automation.PowerShell.Create())')
[void]$sb.AppendLine('                    {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                        Console.CancelKeyPress += new ConsoleCancelEventHandler(delegate (object sender, ConsoleCancelEventArgs e)')
    [void]$sb.AppendLine('                        {')
    [void]$sb.AppendLine('                            try')
    [void]$sb.AppendLine('                            {')
    [void]$sb.AppendLine('                                powershell.BeginStop(new AsyncCallback(delegate (IAsyncResult r)')
    [void]$sb.AppendLine('                                {')
    [void]$sb.AppendLine('                                    mre.Set();')
    [void]$sb.AppendLine('                                    e.Cancel = true;')
    [void]$sb.AppendLine('                                }), null);')
    [void]$sb.AppendLine('                            }')
    [void]$sb.AppendLine('                            catch')
    [void]$sb.AppendLine('                            {')
    [void]$sb.AppendLine('                            };')
    [void]$sb.AppendLine('                        });')
}

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        powershell.Runspace = myRunSpace;')
[void]$sb.AppendLine('                        powershell.Streams.Error.DataAdded += new EventHandler<DataAddedEventArgs>(delegate (object sender, DataAddedEventArgs e)')
[void]$sb.AppendLine('                        {')
[void]$sb.AppendLine('                            ui.WriteErrorLine(((PSDataCollection<ErrorRecord>)sender)[e.Index].ToString());')
[void]$sb.AppendLine('                        });')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        PSDataCollection<string> colInput = new PSDataCollection<string>();')

if (-not $Runtime20) {
    [void]$sb.AppendLine('                        if (ConsoleInfo.IsInputRedirected())')
    [void]$sb.AppendLine('                        { // read standard input')
    [void]$sb.AppendLine('                            string sItem = "";')
    [void]$sb.AppendLine('                            while ((sItem = Console.ReadLine()) != null)')
    [void]$sb.AppendLine('                            { // add to powershell pipeline')
    [void]$sb.AppendLine('                                colInput.Add(sItem);')
    [void]$sb.AppendLine('                            }')
    [void]$sb.AppendLine('                        }')
}

[void]$sb.AppendLine('                        colInput.Complete();')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        PSDataCollection<PSObject> colOutput = new PSDataCollection<PSObject>();')
[void]$sb.AppendLine('                        colOutput.DataAdded += new EventHandler<DataAddedEventArgs>(delegate (object sender, DataAddedEventArgs e)')
[void]$sb.AppendLine('                        {')
[void]$sb.AppendLine('                            ui.WriteLine(colOutput[e.Index].ToString());')
[void]$sb.AppendLine('                        });')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        int separator = 0;')
[void]$sb.AppendLine('                        int idx = 0;')
[void]$sb.AppendLine('                        foreach (string s in args)')
[void]$sb.AppendLine('                        {')
[void]$sb.AppendLine('                            if (string.Compare(s, "-Wait", true) == 0)')
[void]$sb.AppendLine('                                paramWait = true;')
[void]$sb.AppendLine('                            else if (s.StartsWith("-Extract", StringComparison.InvariantCultureIgnoreCase))')
[void]$sb.AppendLine('                            {')
[void]$sb.AppendLine('                                string[] s1 = s.Split(new string[] { ":" }, 2, StringSplitOptions.RemoveEmptyEntries);')
[void]$sb.AppendLine('                                if (s1.Length != 2)')
[void]$sb.AppendLine('                                {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                                    Console.WriteLine("If you specify the -extract option you need to add a file for extraction in this way\r\n   -extract:\"<filename>\"");')
}
else {
    [void]$sb.AppendLine('                                    MessageBox.Show("If you specify the -extract option you need to add a file for extraction in this way\r\n   -extract:\"<filename>\"", System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);')
}

[void]$sb.AppendLine('                                    return 1;')
[void]$sb.AppendLine('                                }')
[void]$sb.AppendLine('                                extractFN = s1[1].Trim(new char[] { ''\"'' });')
[void]$sb.AppendLine('                            }')
[void]$sb.AppendLine('                            else if (string.Compare(s, "-End", true) == 0)')
[void]$sb.AppendLine('                            {')
[void]$sb.AppendLine('                                separator = idx + 1;')
[void]$sb.AppendLine('                                break;')
[void]$sb.AppendLine('                            }')
[void]$sb.AppendLine('                            else if (string.Compare(s, "-Debug", true) == 0)')
[void]$sb.AppendLine('                            {')
[void]$sb.AppendLine('                                System.Diagnostics.Debugger.Launch();')
[void]$sb.AppendLine('                                break;')
[void]$sb.AppendLine('                            }')
[void]$sb.AppendLine('                            idx++;')
[void]$sb.AppendLine('                        }')

[void]$sb.AppendLine()

[void]$sb.AppendFormat('                        string script = System.Text.Encoding.UTF8.GetString(System.Convert.FromBase64String(@"{0}"));', $script).AppendLine()

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        if (!string.IsNullOrEmpty(extractFN))')
[void]$sb.AppendLine('                        {')
[void]$sb.AppendLine('                            System.IO.File.WriteAllText(extractFN, script);')
[void]$sb.AppendLine('                            return 0;')
[void]$sb.AppendLine('                        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        powershell.AddScript(script);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        // parse parameters')
[void]$sb.AppendLine('                        string argbuffer = null;')
[void]$sb.AppendLine('                        // regex for named parameters')
[void]$sb.AppendLine('                        System.Text.RegularExpressions.Regex regex = new System.Text.RegularExpressions.Regex(@"^-([^: ]+)[ :]?([^:]*)$");')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        for (int i = separator; i < args.Length; i++)')
[void]$sb.AppendLine('                        {')
[void]$sb.AppendLine('                            System.Text.RegularExpressions.Match match = regex.Match(args[i]);')
[void]$sb.AppendLine('                            if (match.Success && match.Groups.Count == 3)')
[void]$sb.AppendLine('                            { // parameter in powershell style, means named parameter found')
[void]$sb.AppendLine('                                if (argbuffer != null) // already a named parameter in buffer, then flush it')
[void]$sb.AppendLine('                                    powershell.AddParameter(argbuffer);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                                if (match.Groups[2].Value.Trim() == "")')
[void]$sb.AppendLine('                                { // store named parameter in buffer')
[void]$sb.AppendLine('                                    argbuffer = match.Groups[1].Value;')
[void]$sb.AppendLine('                                }')
[void]$sb.AppendLine('                                else')
[void]$sb.AppendLine('                                    // caution: when called in powershell $true gets converted, when called in cmd.exe not')

[void]$sb.AppendFormat('                                    if ((match.Groups[2].Value == "{0}") || (match.Groups[2].Value.ToUpper() == "\x24" + "TRUE"))', $true).AppendLine()

[void]$sb.AppendLine('                                { // switch found')
[void]$sb.AppendLine('                                    powershell.AddParameter(match.Groups[1].Value, true);')
[void]$sb.AppendLine('                                    argbuffer = null;')
[void]$sb.AppendLine('                                }')
[void]$sb.AppendLine('                                else')
[void]$sb.AppendLine('                                    // caution: when called in powershell $false gets converted, when called in cmd.exe not')

[void]$sb.AppendFormat('                                    if ((match.Groups[2].Value == "{0}") || (match.Groups[2].Value.ToUpper() == "\x24" + "FALSE"))', $false).AppendLine()

[void]$sb.AppendLine('                                { // switch found')
[void]$sb.AppendLine('                                    powershell.AddParameter(match.Groups[1].Value, false);')
[void]$sb.AppendLine('                                    argbuffer = null;')
[void]$sb.AppendLine('                                }')
[void]$sb.AppendLine('                                else')
[void]$sb.AppendLine('                                { // named parameter with value found')
[void]$sb.AppendLine('                                    powershell.AddParameter(match.Groups[1].Value, match.Groups[2].Value);')
[void]$sb.AppendLine('                                    argbuffer = null;')
[void]$sb.AppendLine('                                }')
[void]$sb.AppendLine('                            }')
[void]$sb.AppendLine('                            else')
[void]$sb.AppendLine('                            { // unnamed parameter found')
[void]$sb.AppendLine('                                if (argbuffer != null)')
[void]$sb.AppendLine('                                { // already a named parameter in buffer, so this is the value')
[void]$sb.AppendLine('                                    powershell.AddParameter(argbuffer, args[i]);')
[void]$sb.AppendLine('                                    argbuffer = null;')
[void]$sb.AppendLine('                                }')
[void]$sb.AppendLine('                                else')
[void]$sb.AppendLine('                                { // position parameter found')
[void]$sb.AppendLine('                                    powershell.AddArgument(args[i]);')
[void]$sb.AppendLine('                                }')
[void]$sb.AppendLine('                            }')
[void]$sb.AppendLine('                        }')
[void]$sb.AppendLine()
[void]$sb.AppendLine('                        if (argbuffer != null) powershell.AddParameter(argbuffer); // flush parameter buffer...')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        // convert output to strings')
[void]$sb.AppendLine('                        powershell.AddCommand("out-string");')
[void]$sb.AppendLine('                        // with a single string per line')
[void]$sb.AppendLine('                        powershell.AddParameter("stream");')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        powershell.BeginInvoke<string, PSObject>(colInput, colOutput, null, new AsyncCallback(delegate (IAsyncResult ar)')
[void]$sb.AppendLine('                        {')
[void]$sb.AppendLine('                            if (ar.IsCompleted)')
[void]$sb.AppendLine('                                mre.Set();')
[void]$sb.AppendLine('                        }), null);')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        while (!me.ShouldExit && !mre.WaitOne(100))')
[void]$sb.AppendLine('                        { };')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        powershell.Stop();')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                        if (powershell.InvocationStateInfo.State == PSInvocationState.Failed)')
[void]$sb.AppendLine('                            ui.WriteErrorLine(powershell.InvocationStateInfo.Reason.Message);')
[void]$sb.AppendLine('                    }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('                    myRunSpace.Close();')
[void]$sb.AppendLine('                }')
[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            catch (Exception ex)')
[void]$sb.AppendLine('            {')

if (-not $NoError) {
    if (-not $NoConsole) {
        [void]$sb.AppendLine('                Console.Write("An exception occured: ");')
        [void]$sb.AppendLine('                Console.WriteLine(ex.Message);')
    }
    else {
        [void]$sb.AppendLine('                MessageBox.Show("An exception occured: " + ex.Message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);')
    }
}

[void]$sb.AppendLine('            }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('            if (paramWait)')
[void]$sb.AppendLine('            {')

if (-not $NoConsole) {
    [void]$sb.AppendLine('                Console.WriteLine("Hit any key to exit...");')
    [void]$sb.AppendLine('                Console.ReadKey();')
}
else {
    [void]$sb.AppendLine('                MessageBox.Show("Click OK to exit...", System.AppDomain.CurrentDomain.FriendlyName);')
}

[void]$sb.AppendLine('            }')
[void]$sb.AppendLine('            return me.ExitCode;')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('        static void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)')
[void]$sb.AppendLine('        {')
[void]$sb.AppendLine('            throw new Exception("Unhandled exception in PS2EXE");')
[void]$sb.AppendLine('        }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('    }')

[void]$sb.AppendLine()
[void]$sb.AppendLine('}')

#endregion

#endregion

#endregion


$config20 = New-Object -TypeName System.Text.StringBuilder
$config40 = New-Object -TypeName System.Text.StringBuilder

[void]$config20.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
[void]$config20.AppendLine('<configuration>')
[void]$config20.AppendLine('  <startup>')
[void]$config20.AppendLine('    <supportedRuntime version="v2.0.50727"/>')
[void]$config20.AppendLine('  </startup>')
[void]$config20.AppendLine('</configuration>')


[void]$config40.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
[void]$config40.AppendLine('<configuration>')
[void]$config40.AppendLine('  <startup>')
[void]$config40.AppendLine('    <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.0"/>')
[void]$config40.AppendLine('  </startup>')

if ($LongPaths) {
    [void]$config40.AppendLine('  <runtime>')
    [void]$config40.AppendLine('    <AppContextSwitchOverrides value="Switch.System.IO.UseLegacyPathHandling=false;Switch.System.IO.BlockLongPaths=false"/>')
    [void]$config40.AppendLine('  </runtime>')
}

[void]$config40.AppendLine('</configuration>')


Write-Output 'Compiling file...'

$compilerResults = $codeProvider.CompileAssemblyFromSource($compilerParameters, $sb.ToString())

if ($compilerResults.Errors.Count -gt 0) {
    if (Test-Path -Path $OutputFile) {
        Remove-Item $OutputFile -Verbose:$false
    }

    Write-Error 'Could not create the PowerShell executable because of compilation errors. Use -Verbose parameter to see details.' -ErrorAction Continue
    $compilerResults.Errors | ForEach-Object { Write-Verbose $_ -Verbose:$PSBoundParameters.ContainsKey('Verbose') }
}
else {
    if (Test-Path -Path $OutputFile) {
        Write-Output ('Output file {0} written' -f $OutputFile)

        if ($PSBoundParameters.ContainsKey('Debug')) {
            $compilerResults.TempFiles | Where-Object { $_ -like "*.cs" } | Select-Object -First 1 | ForEach-Object {
                $source = (
                    [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($OutputFile),
                        [System.IO.Path]::GetFileNameWithoutExtension($OutputFile) + '.cs'
                    )
                )

                Write-Output ('Source file name for debug copied: {0}' -f $source)
                Copy-Item -Path $_ -Destination $source -Force
            }

            $compilerResults.TempFiles | Remove-Item -Verbose:$false -Force -ErrorAction SilentlyContinue
        }

        if ($ConfigFile) {
            if ($Runtime20) { $config20 | Set-Content ($OutputFile + '.config') -Encoding UTF8 }
            if ($Runtime40) { $config40 | Set-Content ($OutputFile + '.config') -Encoding UTF8 }

            Write-Output 'Config file for executable created'
        }
    }
    else {
        Write-Error ('Output file {0} not written' -f $OutputFile) -ErrorAction Continue
    }
}

if ($RequireAdmin -or $SupportOS -or $LongPaths) {
    if (Test-Path -Path ($OutputFile + '.win32manifest')) {
        Remove-Item -Path ($OutputFile + '.win32manifest') -Force -Verbose:$false
    }
}
