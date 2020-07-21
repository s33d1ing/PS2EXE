#Requires -Version 2.0

<#
    .SYNOPSIS
        Converts PowerShell scripts to standalone executables

    .DESCRIPTION
        Converts PowerShell scripts to standalone executables. GUI output and input is activated with one switch,
        real Windows executables are generated. You may use the graphical front end "Win-PS2EXE" for convenience

        Please see Remarks on project page for topics "GUI mode output formatting", "Config files",
        "Password security", "Script variables" and "Window in background in -NoConsole mode"

        The generated executables has the following reserved parameters:

            -Debug              Forces the executable to be debugged by calling "System.Diagnostics.Debugger.Break()"

            -Extract:<Path>     Extracts the PowerShell script inside the executable and saves it as the specified Path
                                The script will not be executed.

            -Wait               Pauses at the end of the script execution and waits for a key to be pressed

            -End                All following options will be passed to the script inside the executable
                                All preceding options are used by the executable itself

    .PARAMETER InputFile
        PowerShell script that you want to convert to executable

    .PARAMETER OutputFile
        Destination executable file name, defaults to InputFile with extension ".exe"

    .PARAMETER IconFile
        Icon file name for the compiled executable

    .PARAMETER FileDescription
        Alias: AssemblyTitle

        Displayed as File Description in details tab of File Explorer's properties dialog

    .PARAMETER FileVersion
        Alias: AssemblyFileVersion

        Displayed as File Version in details tab of File Explorer's properties dialog

    .PARAMETER ProductName
        Alias: AssemblyProduct

        Displayed as Product Name in details tab of File Explorer's properties dialog

    .PARAMETER ProductVersion
        Alias: AssemblyInformationalVersion

        Displayed as Product Version in details tab of File Explorer's properties dialog

    .PARAMETER LegalCopyright
        Alias: AssemblyCopyright

        Displayed as Copyright in details tab of File Explorer's properties dialog

    .PARAMETER LegalTrademark
        Alias: AssemblyTrademark

        Displayed as Legal Trademark in details tab of File Explorer's properties dialog

    .PARAMETER CompanyName
        Alias: AssemblyCompany

        Not displayed in File Explorer, but embedded in executable

    .PARAMETER Comments
        Alias: AssemblyDescription

        Not displayed in File Explorer, but embedded in executable

    .PARAMETER Runtime
        Choose between generating a config file that contains the "support .NET Framework versions" settings
        for .NET Framework 2.0/3.x for PowerShell 2.0 or for .NET Framework 4.x for PowerShell 3.0 or higher

    .PARAMETER Platform
        Choose between compiling for AnyCPU, or 32-bit or 64-bit runtime only

    .PARAMETER Apartment
        Choose between a single-threaded apartment or a multithreaded apartment

    .PARAMETER LCID
        Location ID for the compiled executable. Current user culture if not specified

    .PARAMETER NoConfigFile
        Do not write a config file (<OutputFile>.exe.config)

    .PARAMETER NoConsole
        The resulting executable will be a Windows Forms app without a console window.

        You might want to pipe your output to Out-String to prevent a message box for every line of output
        (Example: dir C:\ | Out-String)

    .PARAMETER NoOutput
        The resulting executable will generate no standard output (includes verbose and information channel)

    .PARAMETER NoError
        The resulting executable will generate no error output (includes warning and debug channel)

    .PARAMETER NoVisualStyles
        Disables Visual Styles for a generated Windows GUI application (only applicable with parameter -NoConsole)

    .PARAMETER CredentialGui
        Use GUI for prompting credentials in console mode instead of console input

    .PARAMETER RequireAdmin
        If UAC is enabled, compiled executable will run only in elevated context (UAC dialog appears if required)

    .PARAMETER SupportedOS
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

    .INPUTS
        A PowerShell script (.ps1)

    .OUTPUTS
        An executable file (.exe or .com)

    .NOTES
        Version: 0.6.1.1
        Date: 2020-07-21
        Author: Ingo Karstein, Markus Scholtes, Garrett Dees

        PowerShell 2.0 incompatibilities:
            -in and -notin operators
            DontShow parameter attribute
            NET class new() method
            $PSItem pipeline variable
            -ErrorAction Ignore

    .LINK
        https://gallery.technet.microsoft.com/PS2EXE-GUI-Convert-e7cb69d5
#>


[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$InputFile,
    [Parameter(Position = 1)]
    [string]$OutputFile,
    [Parameter(Position = 2)]
    [string]$IconFile,

    [Alias('AssemblyTitle')]
    [string]$FileDescription,
    [Alias('AssemblyFileVersion')]
    [string]$FileVersion,
    [Alias('AssemblyProduct')]
    [string]$ProductName,
    [Alias('AssemblyInformationalVersion')]
    [string]$ProductVersion,
    [Alias('AssemblyCopyright')]
    [string]$LegalCopyright,
    [Alias('AssemblyTrademark')]
    [string]$LegalTrademark,

    [Alias('AssemblyCompany')]
    [string]$CompanyName,
    [Alias('AssemblyDescription')]
    [string]$Comments,

    [ValidateSet('2.0', '4.0')]
    [string]$Runtime,
    [ValidateSet('AnyCPU', 'x86', 'x64')]
    [string]$Platform,
    [ValidateSet('STA', 'MTA')]
    [string]$Apartment,

    [System.Nullable[int]]$LCID,

    [bool]$NoConfigFile = $true,

    [switch]$NoConsole,
    [switch]$NoOutput,
    [switch]$NoError,
    [switch]$NoVisualStyles,

    [switch]$CredentialGui,
    [switch]$RequireAdmin,
    [switch]$SupportedOS,
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
<##      PS2EXE-GUI v0.6.1.1                                                   ##>
<##      Written by: Ingo Karstein (http://blog.karstein-consulting.com)       ##>
<##      Reworked and GUI support by Markus Scholtes                           ##>
<##      Refactor by Garrett Dees                                              ##>
<##                                                                            ##>
<##      This script is released under Microsoft Public Licence                ##>
<##          that can be downloaded here:                                      ##>
<##          https://choosealicense.com/licenses/ms-pl/                        ##>
<##                                                                            ##>
<############################################################################## #>


if (-not $Nested) {
    Write-Host 'PS2EXE-GUI v0.6.1.1 by Ingo Karstein'
    Write-Host 'Reworked and GUI support by Markus Scholtes'
    Write-Host 'Refactor by Garrett Dees'
}


if ([string]::IsNullOrEmpty($InputFile)) {
    $help = New-Object -TypeName System.Text.StringBuilder

    [void]$help.AppendLine()
    [void]$help.AppendLine('Usage:')
    [void]$help.AppendLine()
    [void]$help.AppendLine('ps2exe.ps1 [-InputFile] <string> [[-OutputFile] <string>] [[-IconFile] <string>]')
    [void]$help.AppendLine()
    [void]$help.AppendLine('    [-FileDescription <string>] [-FileVersion <string>] [-ProductName <string>] [-ProductVersion <string>]')
    [void]$help.AppendLine('    [-LegalCopyright <string>] [-LegalTrademark <string>] [-CompanyName <string>] [-Comments <string>]')
    [void]$help.AppendLine()
    [void]$help.AppendLine('    [-Runtime {2.0 | 4.0}] [-Platform {AnyCPU | x86 | x64}] [-Apartment {STA | MTA}] [-LCID <ID>]')
    [void]$help.AppendLine()
    [void]$help.AppendLine('    [-NoConfigFile:<bool>] [-NoConsole] [-NoOutput] [-NoError] [-NoVisualStyles]')
    [void]$help.AppendLine('    [-CredentialGui] [-RequireAdmin] [-SupportOS] [-Virtualize] [-LongPaths]')
    [void]$help.AppendLine()
    [void]$help.AppendLine()
    [void]$help.AppendLine('       InputFile = PowerShell script that you want to convert to executable')
    [void]$help.AppendLine('      OutputFile = Destination executable file name, defaults to InputFile with extension ".exe"')
    [void]$help.AppendLine('        IconFile = Icon file name for the compiled executable')
    [void]$help.AppendLine()
    [void]$help.AppendLine(' FileDescription = AssemblyTitle (File Description in details tab of File Explorer''s properties dialog)')
    [void]$help.AppendLine('     FileVersion = AssemblyFileVersion (File Version in details tab of File Explorer''s properties dialog)')
    [void]$help.AppendLine('     ProductName = AssemblyProduct (Product Name in details tab of File Explorer''s properties dialog)')
    [void]$help.AppendLine('  ProductVersion = AssemblyInformationalVersion (Product Version in details tab of File Explorer''s properties dialog)')
    [void]$help.AppendLine('  LegalCopyright = AssemblyCopyright (Copyright in details tab of File Explorer''s properties dialog)')
    [void]$help.AppendLine('  LegalTrademark = AssemblyTrademark (Legal Trademark in details tab of File Explorer''s properties dialog)')
    [void]$help.AppendLine('     CompanyName = AssemblyCompany (Not displayed in File Explorer, but embedded in executable)')
    [void]$help.AppendLine('        Comments = AssemblyDescription (Not displayed in File Explorer, but embedded in executable)')
    [void]$help.AppendLine()
    [void]$help.AppendLine('         Runtime = Choose between generating a config file that contains the "support .NET Framework versions" settings')
    [void]$help.AppendLine('                   for .NET Framework 2.0/3.x for PowerShell 2.0 or for .NET Framework 4.x for PowerShell 3.0 or higher')
    [void]$help.AppendLine('        Platform = Choose between compiling for AnyCPU, or 32-bit or 64-bit runtime only')
    [void]$help.AppendLine('       Apartment = Choose between a single-threaded apartment or a multithreaded apartment')
    [void]$help.AppendLine('            LCID = Location ID for the compiled executable. Current user culture if not specified')
    [void]$help.AppendLine()
    [void]$help.AppendLine('    NoConfigFile = Do not write a config file (<OutputFile>.exe.config)')
    [void]$help.AppendLine('       NoConsole = The resulting executable will be a Windows Forms application without a console window')
    [void]$help.AppendLine('        NoOutput = The resulting executable will generate no standard output (includes verbose and information streams)')
    [void]$help.AppendLine('         NoError = The resulting executable will generate no error output (includes warning and debug streams)')
    [void]$help.AppendLine('  NoVisualStyles = Disables visual styles for a generated windows GUI application (only applicable with parameter -NoConsole)')
    [void]$help.AppendLine('   CredentialGui = Use GUI for prompting credentials in console mode instead of console input')
    [void]$help.AppendLine('    RequireAdmin = If UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required)')
    [void]$help.AppendLine('     SupportedOS = Use functions of newest Windows versions (run [System.Environment]::OSVersion to see version)')
    [void]$help.AppendLine('      Virtualize = Application virtualization is activated (forcing x86 runtime)')
    [void]$help.AppendLine('       LongPaths = Enable long paths (>260 characters) if enabled on OS (only works with Windows 10)')
    [void]$help.AppendLine()
    [void]$help.AppendLine()
    [void]$help.AppendLine('Input file not specified!')
    [void]$help.AppendLine()

    Write-Host $help.ToString()

    # exit
    return
}


$PSVersion = $PSVersionTable.PSVersion.Major

if ($PSVersion -ge 4) { Write-Verbose 'You are using PowerShell 4.0 or above.' }
elseif ($PSVersion -eq 3) { Write-Verbose 'You are using PowerShell 3.0.' }
elseif ($PSVersion -eq 2) { Write-Verbose 'You are using PowerShell 2.0.' }
else { Write-Error 'The PowerShell version is unknown!' }


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


if (-not [string]::IsNullOrEmpty($FileVersion)) {
    if ($FileVersion -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?(?:\.(0|[1-9]\d*))?$') {
        Write-Error 'File Version number must follow the Assembly Versioning specification!'
    }
}

if (-not [string]::IsNullOrEmpty($ProductVersion)) {
    if ($ProductVersion -notmatch (
        '^(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?(?:\.(0|[1-9]\d*))?' + `
        '(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?' + `
        '(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
    )) {
        Write-Error 'Product Version number must follow the Semantic Versioning specification!'
    }
}


# Set the default runtime based on PowerShell version
if ([string]::IsNullOrEmpty($Runtime)) {
    if ($PSVersion -ge 3) { $Runtime = '4.0' }
    else { $Runtime = '2.0' }
}

# Set the default apartment model based on PowerShell version
if ([string]::IsNullOrEmpty($Apartment)) {
    if ($PSVersion -ge 3) { $Apartment = 'STA' }
    else { $Apartment = 'MTA' }
}


if ($RequireAdmin -and $Virtualize) {
    Write-Error '-RequireAdmin and -Virtualize cannot be combined!'
}

if ($SupportedOS -and $Virtualize) {
    Write-Error '-SupportOS and -Virtualize cannot be combined!'
}

if ($LongPaths -and $Virtualize) {
    Write-Error '-LongPaths and -Virtualize cannot be combined!'
}

if ($LongPaths -and ($Runtime -eq '2.0')) {
    Write-Error '-LongPaths and -Runtime20 cannot be combined!'
}

if ($Runtime20 -and ($Runtime -eq '4.0')) {
    Write-Error '-Runtime20 and -Runtime40 cannot be combined!'
}

if (($PSVersion -lt 3) -and ($Runtime -eq '4.0')) {
    Write-Error 'You need to run PS2EXE in an PowerShell 3.0 or higher environment to Runtime 4.0'
}


if ($NoConfigFile -and $LongPaths) {
    Write-Warning 'Forcing generation of a config file because long paths requires it.'
    $NoConfigFile = $false
}

#endregion


if (($PSVersion -ge 3) -and ($Runtime -eq '2.0')) {
    Write-Host 'To create an executable for PowerShell 2.0 in PowerShell 3.0 or above, this script will relaunch in PowerShell 2.0...'

    if ($MyInvocation.MyCommand.CommandType -ne 'ExternalScript') {
        Write-Error ('Runtime 2.0 is not supported for compiled ps2exe.ps1 scripts. Compile ps2exe.ps1 with parameter ' + `
            '"-Runtime ''2.0''" and call the generated executable without "-Runtime ''2.0''".') -ErrorAction Continue

        # exit
        return
    }


    $arguments = New-Object -TypeName System.Text.StringBuilder

    [void]$arguments.AppendFormat('-InputFile "{0}" -OutputFile "{1}"', $InputFile, $OutputFile)

    if (-not [string]::IsNullOrEmpty($IconFile)) { [void]$arguments.AppendFormat(' -IconFile "{0}"', $IconFile) }

    if (-not [string]::IsNullOrEmpty($FileDescription)) { [void]$arguments.AppendFormat(' -FileDescription "{0}"', $FileDescription) }
    if (-not [string]::IsNullOrEmpty($FileVersion)) { [void]$arguments.AppendFormat(' -FileVersion "{0}"', $FileVersion) }
    if (-not [string]::IsNullOrEmpty($ProductName)) { [void]$arguments.AppendFormat(' -ProductName "{0}"', $ProductName) }
    if (-not [string]::IsNullOrEmpty($ProductVersion)) { [void]$arguments.AppendFormat(' -ProductVersion "{0}"', $ProductVersion) }
    if (-not [string]::IsNullOrEmpty($LegalCopyright)) { [void]$arguments.AppendFormat(' -LegalCopyright "{0}"', $LegalCopyright) }
    if (-not [string]::IsNullOrEmpty($LegalTrademark)) { [void]$arguments.AppendFormat(' -LegalTrademark "{0}"', $LegalTrademark) }
    if (-not [string]::IsNullOrEmpty($CompanyName)) { [void]$arguments.AppendFormat(' -CompanyName "{0}"', $CompanyName) }
    if (-not [string]::IsNullOrEmpty($Comments)) { [void]$arguments.AppendFormat(' -Comments "{0}"', $Comments) }

    # Only add the following three arguments if they were provided by the user and not auto populated
    if ($PSBoundParameters.ContainsKey($Runtime)) { [void]$arguments.AppendFormat(' -Runtime "{0}"', $Runtime) }
    if ($PSBoundParameters.ContainsKey($Platform)) { [void]$arguments.AppendFormat(' -Platform "{0}"', $Platform) }
    if ($PSBoundParameters.ContainsKey($Apartment)) { [void]$arguments.AppendFormat(' -Apartment "{0}"', $Apartment) }

    if ($null -ne $LCID) { [void]$arguments.AppendFormat(' -LCID {0}', $LCID) }

    if ($NoConfigFile.IsPresent) { [void]$arguments.Append(' -NoConfigFile') }

    if ($NoConsole.IsPresent) { [void]$arguments.Append(' -NoConsole') }
    if ($NoOutput.IsPresent) { [void]$arguments.Append(' -NoOutput') }
    if ($NoError.IsPresent) { [void]$arguments.Append(' -NoError') }

    if ($CredentialGui.IsPresent) { [void]$arguments.Append(' -CredentialGui') }
    if ($RequireAdmin.IsPresent) { [void]$arguments.Append(' -RequireAdmin') }
    if ($SupportedOS.IsPresent) { [void]$arguments.Append(' -SupportedOS') }
    if ($Virtualize.IsPresent) { [void]$arguments.Append(' -Virtualize') }
    if ($LongPaths.IsPresent) { [void]$arguments.Append(' -LongPaths') }

    if (-not $Nested.IsPresent) { [void]$arguments.Append(' -Nested') }

    if ($PSBoundParameters.ContainsKey('Debug')) { [void]$arguments.Append(' -Debug') }
    if ($PSBoundParameters.ContainsKey('Verbose')) { [void]$arguments.Append(' -Verbose') }


    $command = '. PowerShell.exe -Version 2.0 -Command ''& "{0}" {1}''' -f $PSCommandPath, $arguments.ToString()

    Write-Debug ('Invoking: {0}' -f $command)
    Invoke-Expression -Command $command.Replace('"', '\"')

    # exit
    return
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
        Write-Warning 'No .Net 3.5 compiler found, using .Net 2.0 compiler. Some methods will not be available!'
        $options.Add('CompilerVersion', 'v2.0')
        $Compiler = '2.0'
    }
}


$assembies.Add('System.dll')

$assembies.Add((([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
    $_.ManifestModule.Name -eq 'System.Management.Automation.dll'
} | Select-Object -First 1) | Select-Object -ExpandProperty Location))

if ($Runtime -eq '4.0') {
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

    if ($Runtime -eq '4.0') {
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
$compilerParameters = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters -ArgumentList $assembies, $OutputFile

$compilerParameters.GenerateInMemory = $false
$compilerParameters.GenerateExecutable = $true

# Valid choices for /platform: are AnyCPU, x86, and x64
if ([string]::IsNullOrEmpty($Platform)) { $Platform = 'AnyCPU' }

if ($NoConsole) { $target = 'winexe' } else { $target =  'exe' }

if (-not ([string]::IsNullOrEmpty($IconFile))) {
    $win32icon = '"/win32icon:{0}"' -f $IconFile
}

if ($RequireAdmin -or $SupportedOS -or $LongPaths) {
    $win32manifest = '"/win32manifest:{0}.win32manifest"' -f $OutputFile

    $manifest = New-Object -TypeName System.Text.StringBuilder

    [void]$manifest.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$manifest.AppendLine('<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">')

    if ($LongPaths) {
        [void]$manifest.AppendLine('  <application xmlns="urn:schemas-microsoft-com:asm.v3">')
        [void]$manifest.AppendLine('    <windowsSettings>')
        [void]$manifest.AppendLine('      <longPathAware xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">true</longPathAware>')
        [void]$manifest.AppendLine('    </windowsSettings>')
        [void]$manifest.AppendLine('  </application>')
    }

    if ($RequireAdmin) {
        [void]$manifest.AppendLine('  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">')
        [void]$manifest.AppendLine('    <security>')
        [void]$manifest.AppendLine('      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">')
        [void]$manifest.AppendLine('        <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>')
        [void]$manifest.AppendLine('      </requestedPrivileges>')
        [void]$manifest.AppendLine('    </security>')
        [void]$manifest.AppendLine('  </trustInfo>')
    }

    if ($SupportedOS) {
        [void]$manifest.AppendLine('  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">')
        [void]$manifest.AppendLine('    <application>')
        [void]$manifest.AppendLine('      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/> // Windows 10')
        [void]$manifest.AppendLine('      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/> // Windows 8.1')
        [void]$manifest.AppendLine('      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/> // Windows 8')
        [void]$manifest.AppendLine('      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/> // Windows 7')
        [void]$manifest.AppendLine('      <supportedOS Id="{e2011457-1546-43c5-a5fe-008deee3d3f0}"/> // Windows Vista')
        [void]$manifest.AppendLine('    </application>')
        [void]$manifest.AppendLine('  </compatibility>')
    }

    [void]$manifest.AppendLine('</assembly>')

    $manifest.ToString() -replace '\s*$' | Set-Content -Path ($OutputFile + '.win32manifest') -Encoding UTF8
}


if (-not $Virtualize) {
    $compilerParameters.CompilerOptions = '/platform:{0} /target:{1} {2} {3}' -f $platform.ToLower(), $target, $win32icon, $win32manifest
}
else {
    Write-Warning 'Application virtualization is activated, forcing x86 platfom.'
    $compilerParameters.CompilerOptions = '/platform:x86 /target:{0} {1} /nowin32manifest' -f $target, $win32icon
}


$compilerParameters.IncludeDebugInformation = $PSBoundParameters.ContainsKey('Debug')
$compilerParameters.TempFiles.KeepFiles = $PSBoundParameters.ContainsKey('Debug')


Write-Host ('Reading input file "{0}"' -f $InputFile)

$content = Get-Content -LiteralPath $InputFile -Encoding UTF8 -ErrorAction SilentlyContinue

if ([string]::IsNullOrEmpty($content)) {
    Write-Error 'No data found. May be read error or file protected.'
}

$joined = [System.String]::Join([System.Environment]::NewLine, $content)
$script = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($joined))


$culture = New-Object -TypeName System.Text.StringBuilder

if ($null -ne $LCID) {
    [void]$culture.AppendFormat('System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.GetCultureInfo({0});', $LCID).AppendLine()
    [void]$culture.AppendFormat('System.Threading.Thread.CurrentThread.CurrentUICulture = System.Globalization.CultureInfo.GetCultureInfo({0});', $LCID).AppendLine()
}

#endregion


#region Program Framework

$framework = New-Object -TypeName System.Text.StringBuilder

[void]$framework.AppendLine('// Simple PowerShell host created by Ingo Karstein (https://blog.kenaro.com) for PS2EXE')
[void]$framework.AppendLine('// Reworked and GUI support by Markus Scholtes')
[void]$framework.AppendLine('// Refactor by Garrett Dees')

[void]$framework.AppendLine()
[void]$framework.AppendLine('using System;')
[void]$framework.AppendLine('using System.Collections.Generic;')
[void]$framework.AppendLine('using System.Text;')
[void]$framework.AppendLine('using System.Management.Automation;')
[void]$framework.AppendLine('using System.Management.Automation.Runspaces;')
[void]$framework.AppendLine('using PowerShell = System.Management.Automation.PowerShell;')
[void]$framework.AppendLine('using System.Globalization;')
[void]$framework.AppendLine('using System.Management.Automation.Host;')
[void]$framework.AppendLine('using System.Security;')
[void]$framework.AppendLine('using System.Reflection;')
[void]$framework.AppendLine('using System.Runtime.InteropServices;')

if ($NoConsole) {
    [void]$framework.AppendLine('using System.Windows.Forms;')
    [void]$framework.AppendLine('using System.Drawing;')
}

[void]$framework.AppendLine()
[void]$framework.AppendFormat('[assembly: AssemblyTitle("{0}")]', $FileDescription.Replace('\', '\\')).AppendLine()
[void]$framework.AppendFormat('[assembly: AssemblyDescription("{0}")]', $Comments.Replace('\', '\\')).AppendLine()
[void]$framework.AppendFormat('[assembly: AssemblyCompany("{0}")]', $CompanyName.Replace('\', '\\')).AppendLine()
[void]$framework.AppendFormat('[assembly: AssemblyProduct("{0}")]', $ProductName.Replace('\', '\\')).AppendLine()
[void]$framework.AppendFormat('[assembly: AssemblyCopyright("{0}")]', $LegalCopyright.Replace('\', '\\')).AppendLine()
[void]$framework.AppendFormat('[assembly: AssemblyTrademark("{0}")]', $LegalTrademark.Replace('\', '\\')).AppendLine()

if (-not [string]::IsNullOrEmpty($FileVersion)) {
    $major, $minor = $FileVersion.Split('.') | Select-Object -First 2

    [void]$framework.AppendFormat('[assembly: AssemblyVersion("{0}.{1}")]', $major, $minor).AppendLine()
    [void]$framework.AppendFormat('[assembly: AssemblyFileVersion("{0}")]', $FileVersion).AppendLine()
}

if (-not [string]::IsNullOrEmpty($ProductVersion)) {
    [void]$framework.AppendFormat('[assembly: AssemblyInformationalVersion("{0}")]', $ProductVersion).AppendLine()
}

#region PowerShell Host

[void]$framework.AppendLine()
[void]$framework.AppendLine('namespace ik.PowerShell')
[void]$framework.AppendLine('{')

#region Credential Form

if ($NoConsole -or $CredentialGui) {
    [void]$framework.AppendLine()
    [void]$framework.AppendLine('    internal class CredentialForm')
    [void]$framework.AppendLine('    {')
    [void]$framework.AppendLine('        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]')
    [void]$framework.AppendLine('        private struct CREDUI_INFO')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            public int cbSize;')
    [void]$framework.AppendLine('            public IntPtr hwndParent;')
    [void]$framework.AppendLine('            public string pszMessageText;')
    [void]$framework.AppendLine('            public string pszCaptionText;')
    [void]$framework.AppendLine('            public IntPtr hbmBanner;')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        [Flags]')
    [void]$framework.AppendLine('        enum CREDUI_FLAGS')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            INCORRECT_PASSWORD = 0x1,')
    [void]$framework.AppendLine('            DO_NOT_PERSIST = 0x2,')
    [void]$framework.AppendLine('            REQUEST_ADMINISTRATOR = 0x4,')
    [void]$framework.AppendLine('            EXCLUDE_CERTIFICATES = 0x8,')
    [void]$framework.AppendLine('            REQUIRE_CERTIFICATE = 0x10,')
    [void]$framework.AppendLine('            SHOW_SAVE_CHECK_BOX = 0x40,')
    [void]$framework.AppendLine('            ALWAYS_SHOW_UI = 0x80,')
    [void]$framework.AppendLine('            REQUIRE_SMARTCARD = 0x100,')
    [void]$framework.AppendLine('            PASSWORD_ONLY_OK = 0x200,')
    [void]$framework.AppendLine('            VALIDATE_USERNAME = 0x400,')
    [void]$framework.AppendLine('            COMPLETE_USERNAME = 0x800,')
    [void]$framework.AppendLine('            PERSIST = 0x1000,')
    [void]$framework.AppendLine('            SERVER_CREDENTIAL = 0x4000,')
    [void]$framework.AppendLine('            EXPECT_CONFIRMATION = 0x20000,')
    [void]$framework.AppendLine('            GENERIC_CREDENTIALS = 0x40000,')
    [void]$framework.AppendLine('            USERNAME_TARGET_CREDENTIALS = 0x80000,')
    [void]$framework.AppendLine('            KEEP_USERNAME = 0x100000,')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public enum CredUIReturnCodes')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            NO_ERROR = 0,')
    [void]$framework.AppendLine('            ERROR_CANCELLED = 1223,')
    [void]$framework.AppendLine('            ERROR_NO_SUCH_LOGON_SESSION = 1312,')
    [void]$framework.AppendLine('            ERROR_NOT_FOUND = 1168,')
    [void]$framework.AppendLine('            ERROR_INVALID_ACCOUNT_NAME = 1315,')
    [void]$framework.AppendLine('            ERROR_INSUFFICIENT_BUFFER = 122,')
    [void]$framework.AppendLine('            ERROR_INVALID_PARAMETER = 87,')
    [void]$framework.AppendLine('            ERROR_INVALID_FLAGS = 1004,')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        [DllImport("credui", CharSet = CharSet.Unicode)]')
    [void]$framework.AppendLine('        private static extern CredUIReturnCodes CredUIPromptForCredentials(ref CREDUI_INFO creditUR,')
    [void]$framework.AppendLine('            string targetName,')
    [void]$framework.AppendLine('            IntPtr reserved1,')
    [void]$framework.AppendLine('            int iError,')
    [void]$framework.AppendLine('            StringBuilder userName,')
    [void]$framework.AppendLine('            int maxUserName,')
    [void]$framework.AppendLine('            StringBuilder password,')
    [void]$framework.AppendLine('            int maxPassword,')
    [void]$framework.AppendLine('            [MarshalAs(UnmanagedType.Bool)] ref bool pfSave,')
    [void]$framework.AppendLine('            CREDUI_FLAGS flags);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public class UserPwd')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            public string User = string.Empty;')
    [void]$framework.AppendLine('            public string Password = string.Empty;')
    [void]$framework.AppendLine('            public string Domain = string.Empty;')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        internal static UserPwd PromptForPassword(string caption, string message, string target, string user, PSCredentialTypes credTypes, PSCredentialUIOptions options)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            // Flags und Variablen initialisieren')
    [void]$framework.AppendLine('            StringBuilder userPassword = new StringBuilder(), userID = new StringBuilder(user, 128);')
    [void]$framework.AppendLine('            CREDUI_INFO credUI = new CREDUI_INFO();')
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(message)) credUI.pszMessageText = message;')
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(caption)) credUI.pszCaptionText = caption;')
    [void]$framework.AppendLine('            credUI.cbSize = Marshal.SizeOf(credUI);')
    [void]$framework.AppendLine('            bool save = false;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            CREDUI_FLAGS flags = CREDUI_FLAGS.DO_NOT_PERSIST;')
    [void]$framework.AppendLine('            if ((credTypes & PSCredentialTypes.Generic) == PSCredentialTypes.Generic)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                flags |= CREDUI_FLAGS.GENERIC_CREDENTIALS;')
    [void]$framework.AppendLine('                if ((options & PSCredentialUIOptions.AlwaysPrompt) == PSCredentialUIOptions.AlwaysPrompt)')
    [void]$framework.AppendLine('                {')
    [void]$framework.AppendLine('                    flags |= CREDUI_FLAGS.ALWAYS_SHOW_UI;')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // den Benutzer nach Kennwort fragen, grafischer Prompt')
    [void]$framework.AppendLine('            CredUIReturnCodes returnCode = CredUIPromptForCredentials(ref credUI, target, IntPtr.Zero, 0, userID, 128, userPassword, 128, ref save, flags);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (returnCode == CredUIReturnCodes.NO_ERROR)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                UserPwd ret = new UserPwd();')
    [void]$framework.AppendLine('                ret.User = userID.ToString();')
    [void]$framework.AppendLine('                ret.Password = userPassword.ToString();')
    [void]$framework.AppendLine('                ret.Domain = "";')
    [void]$framework.AppendLine('                return ret;')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            return null;')
    [void]$framework.AppendLine('        }')
    [void]$framework.AppendLine('    }')
}

#endregion

#region PS2EXE Host Raw User Interface

[void]$framework.AppendLine()
[void]$framework.AppendLine('    internal class PS2EXEHostRawUI : PSHostRawUserInterface')
[void]$framework.AppendLine('    {')

if ($NoConsole) {
    [void]$framework.AppendLine('        // Speicher für Konsolenfarben bei GUI-Output werden gelesen und gesetzt, aber im Moment nicht genutzt (for future use)')
    [void]$framework.AppendLine('        private ConsoleColor ncBackgroundColor = ConsoleColor.White;')
    [void]$framework.AppendLine('        private ConsoleColor ncForegroundColor = ConsoleColor.Black;')
}
else {
    [void]$framework.AppendLine('        const int STD_OUTPUT_HANDLE = -11;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        //CHAR_INFO struct, which was a union in the old days')
    [void]$framework.AppendLine('        // so we want to use LayoutKind.Explicit to mimic it as closely')
    [void]$framework.AppendLine('        // as we can')
    [void]$framework.AppendLine('        [StructLayout(LayoutKind.Explicit)]')
    [void]$framework.AppendLine('        public struct CHAR_INFO')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            [FieldOffset(0)]')
    [void]$framework.AppendLine('            internal char UnicodeChar;')
    [void]$framework.AppendLine('            [FieldOffset(0)]')
    [void]$framework.AppendLine('            internal char AsciiChar;')
    [void]$framework.AppendLine('            [FieldOffset(2)] //2 bytes seems to work properly')
    [void]$framework.AppendLine('            internal UInt16 Attributes;')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        //COORD struct')
    [void]$framework.AppendLine('        [StructLayout(LayoutKind.Sequential)]')
    [void]$framework.AppendLine('        public struct COORD')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            public short X;')
    [void]$framework.AppendLine('            public short Y;')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        //SMALL_RECT struct')
    [void]$framework.AppendLine('        [StructLayout(LayoutKind.Sequential)]')
    [void]$framework.AppendLine('        public struct SMALL_RECT')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            public short Left;')
    [void]$framework.AppendLine('            public short Top;')
    [void]$framework.AppendLine('            public short Right;')
    [void]$framework.AppendLine('            public short Bottom;')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        /* Reads character and color attribute data from a rectangular block of character cells in a console screen buffer,')
    [void]$framework.AppendLine('             and the function writes the data to a rectangular block at a specified location in the destination buffer. */')
    [void]$framework.AppendLine('        [DllImport("kernel32.dll", EntryPoint = "ReadConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]')
    [void]$framework.AppendLine('        internal static extern bool ReadConsoleOutput(')
    [void]$framework.AppendLine('            IntPtr hConsoleOutput,')
    [void]$framework.AppendLine('            /* This pointer is treated as the origin of a two-dimensional array of CHAR_INFO structures')
    [void]$framework.AppendLine('            whose size is specified by the dwBufferSize parameter.*/')
    [void]$framework.AppendLine('            [MarshalAs(UnmanagedType.LPArray), Out] CHAR_INFO[,] lpBuffer,')
    [void]$framework.AppendLine('            COORD dwBufferSize,')
    [void]$framework.AppendLine('            COORD dwBufferCoord,')
    [void]$framework.AppendLine('            ref SMALL_RECT lpReadRegion);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        /* Writes character and color attribute data to a specified rectangular block of character cells in a console screen buffer.')
    [void]$framework.AppendLine('            The data to be written is taken from a correspondingly sized rectangular block at a specified location in the source buffer */')
    [void]$framework.AppendLine('        [DllImport("kernel32.dll", EntryPoint = "WriteConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]')
    [void]$framework.AppendLine('        internal static extern bool WriteConsoleOutput(')
    [void]$framework.AppendLine('            IntPtr hConsoleOutput,')
    [void]$framework.AppendLine('            /* This pointer is treated as the origin of a two-dimensional array of CHAR_INFO structures')
    [void]$framework.AppendLine('            whose size is specified by the dwBufferSize parameter.*/')
    [void]$framework.AppendLine('            [MarshalAs(UnmanagedType.LPArray), In] CHAR_INFO[,] lpBuffer,')
    [void]$framework.AppendLine('            COORD dwBufferSize,')
    [void]$framework.AppendLine('            COORD dwBufferCoord,')
    [void]$framework.AppendLine('            ref SMALL_RECT lpWriteRegion);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        /* Moves a block of data in a screen buffer. The effects of the move can be limited by specifying a clipping rectangle, so')
    [void]$framework.AppendLine('            the contents of the console screen buffer outside the clipping rectangle are unchanged. */')
    [void]$framework.AppendLine('        [DllImport("kernel32.dll", SetLastError = true)]')
    [void]$framework.AppendLine('        static extern bool ScrollConsoleScreenBuffer(')
    [void]$framework.AppendLine('            IntPtr hConsoleOutput,')
    [void]$framework.AppendLine('            [In] ref SMALL_RECT lpScrollRectangle,')
    [void]$framework.AppendLine('            [In] ref SMALL_RECT lpClipRectangle,')
    [void]$framework.AppendLine('            COORD dwDestinationOrigin,')
    [void]$framework.AppendLine('            [In] ref CHAR_INFO lpFill);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        [DllImport("kernel32.dll", SetLastError = true)]')
    [void]$framework.AppendLine('        static extern IntPtr GetStdHandle(int nStdHandle);')
}


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override ConsoleColor BackgroundColor')
[void]$framework.AppendLine('        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            get { return Console.BackgroundColor; }')
    [void]$framework.AppendLine('            set { Console.BackgroundColor = value; }')
}
else {
    [void]$framework.AppendLine('            get { return ncBackgroundColor; }')
    [void]$framework.AppendLine('            set { ncBackgroundColor = value; }')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override System.Management.Automation.Host.Size BufferSize')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                if (ConsoleInfo.IsOutputRedirected())')
    [void]$framework.AppendLine('                    // return default value for redirection. If no valid value is returned WriteLine will not be called')
    [void]$framework.AppendLine('                    return new System.Management.Automation.Host.Size(120, 50);')
    [void]$framework.AppendLine('                else')
    [void]$framework.AppendLine('                    return new System.Management.Automation.Host.Size(Console.BufferWidth, Console.BufferHeight);')
}
else {
    [void]$framework.AppendLine('                // return default value for Winforms. If no valid value is returned WriteLine will not be called')
    [void]$framework.AppendLine('                return new System.Management.Automation.Host.Size(120, 50);')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            set')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                Console.BufferWidth = value.Width;')
    [void]$framework.AppendLine('                Console.BufferHeight = value.Height;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override Coordinates CursorPosition')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                return new Coordinates(Console.CursorLeft, Console.CursorTop);')
}
else {
    [void]$framework.AppendLine('                // Dummywert für Winforms zurückgeben.')
    [void]$framework.AppendLine('                return new Coordinates(0, 0);')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            set')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                Console.CursorTop = value.Y;')
    [void]$framework.AppendLine('                Console.CursorLeft = value.X;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override int CursorSize')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                return Console.CursorSize;')
}
else {
    [void]$framework.AppendLine('                // Dummywert für Winforms zurückgeben.')
    [void]$framework.AppendLine('                return 25;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            set')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                Console.CursorSize = value;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')


if ($NoConsole){
    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        private Form InvisibleForm = null;')
}


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void FlushInputBuffer()')
[void]$framework.AppendLine('        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            if (!ConsoleInfo.IsInputRedirected())')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                while (Console.KeyAvailable)')
    [void]$framework.AppendLine('                    Console.ReadKey(true);')
    [void]$framework.AppendLine('            }')
}
else {
    [void]$framework.AppendLine('            if (InvisibleForm != null)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                InvisibleForm.Close();')
    [void]$framework.AppendLine('                InvisibleForm = null;')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                InvisibleForm = new Form();')
    [void]$framework.AppendLine('                InvisibleForm.Opacity = 0;')
    [void]$framework.AppendLine('                InvisibleForm.ShowInTaskbar = false;')
    [void]$framework.AppendLine('                InvisibleForm.Visible = true;')
    [void]$framework.AppendLine('            }')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override ConsoleColor ForegroundColor')
[void]$framework.AppendLine('        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            get { return Console.ForegroundColor; }')
    [void]$framework.AppendLine('            set { Console.ForegroundColor = value; }')
} else {
    [void]$framework.AppendLine('            get { return ncForegroundColor; }')
    [void]$framework.AppendLine('            set { ncForegroundColor = value; }')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override BufferCell[,] GetBufferContents(System.Management.Automation.Host.Rectangle rectangle)')
[void]$framework.AppendLine('        {')

if ($Compiler -eq '2.0') {
    [void]$framework.AppendLine('            throw new Exception("Method GetBufferContents not implemented for .Net v2.0 compiler");')
}
else {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);')
        [void]$framework.AppendLine('            CHAR_INFO[,] buffer = new CHAR_INFO[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];')
        [void]$framework.AppendLine('            COORD buffer_size = new COORD() { X = (short)(rectangle.Right - rectangle.Left + 1), Y = (short)(rectangle.Bottom - rectangle.Top + 1) };')
        [void]$framework.AppendLine('            COORD buffer_index = new COORD() { X = 0, Y = 0 };')
        [void]$framework.AppendLine('            SMALL_RECT screen_rect = new SMALL_RECT() { Left = (short)rectangle.Left, Top = (short)rectangle.Top, Right = (short)rectangle.Right, Bottom = (short)rectangle.Bottom };')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            ReadConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            System.Management.Automation.Host.BufferCell[,] ScreenBuffer = new System.Management.Automation.Host.BufferCell[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];')
        [void]$framework.AppendLine('            for (int y = 0; y <= rectangle.Bottom - rectangle.Top; y++)')
        [void]$framework.AppendLine('                for (int x = 0; x <= rectangle.Right - rectangle.Left; x++)')
        [void]$framework.AppendLine('                {')
        [void]$framework.AppendLine('                    ScreenBuffer[y, x] = new System.Management.Automation.Host.BufferCell(buffer[y, x].AsciiChar, (System.ConsoleColor)(buffer[y, x].Attributes & 0xF), (System.ConsoleColor)((buffer[y, x].Attributes & 0xF0) / 0x10), System.Management.Automation.Host.BufferCellType.Complete);')
        [void]$framework.AppendLine('                }')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            return ScreenBuffer;')
    }
    else {
        [void]$framework.AppendLine('            System.Management.Automation.Host.BufferCell[,] ScreenBuffer = new System.Management.Automation.Host.BufferCell[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            for (int y = 0; y <= rectangle.Bottom - rectangle.Top; y++)')
        [void]$framework.AppendLine('                for (int x = 0; x <= rectangle.Right - rectangle.Left; x++)')
        [void]$framework.AppendLine('                {')
        [void]$framework.AppendLine('                    ScreenBuffer[y, x] = new System.Management.Automation.Host.BufferCell('' '', ncForegroundColor, ncBackgroundColor, System.Management.Automation.Host.BufferCellType.Complete);')
        [void]$framework.AppendLine('                }')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            return ScreenBuffer;')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override bool KeyAvailable')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                return Console.KeyAvailable;')
}
else {
    [void]$framework.AppendLine('                return true;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override System.Management.Automation.Host.Size MaxPhysicalWindowSize')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                return new System.Management.Automation.Host.Size(Console.LargestWindowWidth, Console.LargestWindowHeight);')
}
else {
    [void]$framework.AppendLine('                // Dummy-Wert für Winforms')
    [void]$framework.AppendLine('                return new System.Management.Automation.Host.Size(240, 84);')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override System.Management.Automation.Host.Size MaxWindowSize')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                return new System.Management.Automation.Host.Size(Console.BufferWidth, Console.BufferWidth);')
}
else {
    [void]$framework.AppendLine('                // Dummy-Wert für Winforms')
    [void]$framework.AppendLine('                return new System.Management.Automation.Host.Size(120, 84);')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override KeyInfo ReadKey(ReadKeyOptions options)')
[void]$framework.AppendLine('        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            ConsoleKeyInfo cki = Console.ReadKey((options & ReadKeyOptions.NoEcho) != 0);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            ControlKeyStates cks = 0;')
    [void]$framework.AppendLine('            if ((cki.Modifiers & ConsoleModifiers.Alt) != 0)')
    [void]$framework.AppendLine('                cks |= ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;')
    [void]$framework.AppendLine('            if ((cki.Modifiers & ConsoleModifiers.Control) != 0)')
    [void]$framework.AppendLine('                cks |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;')
    [void]$framework.AppendLine('            if ((cki.Modifiers & ConsoleModifiers.Shift) != 0)')
    [void]$framework.AppendLine('                cks |= ControlKeyStates.ShiftPressed;')
    [void]$framework.AppendLine('            if (Console.CapsLock)')
    [void]$framework.AppendLine('                cks |= ControlKeyStates.CapsLockOn;')
    [void]$framework.AppendLine('            if (Console.NumberLock)')
    [void]$framework.AppendLine('                cks |= ControlKeyStates.NumLockOn;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            return new KeyInfo((int)cki.Key, cki.KeyChar, cks, (options & ReadKeyOptions.IncludeKeyDown) != 0);')
}
else {
    [void]$framework.AppendLine('            if ((options & ReadKeyOptions.IncludeKeyDown) != 0)')
    [void]$framework.AppendLine('                return ReadKeyBox.Show("", "", true);')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                return ReadKeyBox.Show("", "", false);')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void ScrollBufferContents(System.Management.Automation.Host.Rectangle source, Coordinates destination, System.Management.Automation.Host.Rectangle clip, BufferCell fill)')
[void]$framework.AppendLine('        { // no destination block clipping implemented')

if (-not $NoConsole) {
    if ($Compiler -eq '2.0') {
        [void]$framework.AppendLine('            throw new Exception("Method ScrollBufferContents not implemented for .Net v2.0 compiler");')
    }
    else {
        [void]$framework.AppendLine('            // clip area out of source range?')
        [void]$framework.AppendLine('            if ((source.Left > clip.Right) || (source.Right < clip.Left) || (source.Top > clip.Bottom) || (source.Bottom < clip.Top))')
        [void]$framework.AppendLine('            { // clipping out of range -> nothing to do')
        [void]$framework.AppendLine('                return;')
        [void]$framework.AppendLine('            }')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);')
        [void]$framework.AppendLine('            SMALL_RECT lpScrollRectangle = new SMALL_RECT() { Left = (short)source.Left, Top = (short)source.Top, Right = (short)(source.Right), Bottom = (short)(source.Bottom) };')
        [void]$framework.AppendLine('            SMALL_RECT lpClipRectangle;')
        [void]$framework.AppendLine('            if (clip != null)')
        [void]$framework.AppendLine('            { lpClipRectangle = new SMALL_RECT() { Left = (short)clip.Left, Top = (short)clip.Top, Right = (short)(clip.Right), Bottom = (short)(clip.Bottom) }; }')
        [void]$framework.AppendLine('            else')
        [void]$framework.AppendLine('            { lpClipRectangle = new SMALL_RECT() { Left = (short)0, Top = (short)0, Right = (short)(Console.WindowWidth - 1), Bottom = (short)(Console.WindowHeight - 1) }; }')
        [void]$framework.AppendLine('            COORD dwDestinationOrigin = new COORD() { X = (short)(destination.X), Y = (short)(destination.Y) };')
        [void]$framework.AppendLine('            CHAR_INFO lpFill = new CHAR_INFO() { AsciiChar = fill.Character, Attributes = (ushort)((int)(fill.ForegroundColor) + (int)(fill.BackgroundColor) * 16) };')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            ScrollConsoleScreenBuffer(hStdOut, ref lpScrollRectangle, ref lpClipRectangle, dwDestinationOrigin, ref lpFill);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void SetBufferContents(System.Management.Automation.Host.Rectangle rectangle, BufferCell fill)')
[void]$framework.AppendLine('        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            // using a trick: move the buffer out of the screen, the source area gets filled with the char fill.Character')
    [void]$framework.AppendLine('            if (rectangle.Left >= 0)')
    [void]$framework.AppendLine('                Console.MoveBufferArea(rectangle.Left, rectangle.Top, rectangle.Right - rectangle.Left + 1, rectangle.Bottom - rectangle.Top + 1, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('            { // Clear-Host: move all content off the screen')
    [void]$framework.AppendLine('                Console.MoveBufferArea(0, 0, BufferSize.Width, BufferSize.Height, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);')
    [void]$framework.AppendLine('            }')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void SetBufferContents(Coordinates origin, BufferCell[,] contents)')
[void]$framework.AppendLine('        {')

if (-not $NoConsole) {
    if ($Compiler -eq '2.0') {
        [void]$framework.AppendLine('            throw new Exception("Method SetBufferContents not implemented for .Net v2.0 compiler");')
    }
    else {
        [void]$framework.AppendLine('            IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);')
        [void]$framework.AppendLine('            CHAR_INFO[,] buffer = new CHAR_INFO[contents.GetLength(0), contents.GetLength(1)];')
        [void]$framework.AppendLine('            COORD buffer_size = new COORD() { X = (short)(contents.GetLength(1)), Y = (short)(contents.GetLength(0)) };')
        [void]$framework.AppendLine('            COORD buffer_index = new COORD() { X = 0, Y = 0 };')
        [void]$framework.AppendLine('            SMALL_RECT screen_rect = new SMALL_RECT() { Left = (short)origin.X, Top = (short)origin.Y, Right = (short)(origin.X + contents.GetLength(1) - 1), Bottom = (short)(origin.Y + contents.GetLength(0) - 1) };')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            for (int y = 0; y < contents.GetLength(0); y++)')
        [void]$framework.AppendLine('                for (int x = 0; x < contents.GetLength(1); x++)')
        [void]$framework.AppendLine('                {')
        [void]$framework.AppendLine('                    buffer[y, x] = new CHAR_INFO() { AsciiChar = contents[y, x].Character, Attributes = (ushort)((int)(contents[y, x].ForegroundColor) + (int)(contents[y, x].BackgroundColor) * 16) };')
        [void]$framework.AppendLine('                }')

        [void]$framework.AppendLine()
        [void]$framework.AppendLine('            WriteConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override Coordinates WindowPosition')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                Coordinates s = new Coordinates();')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                s.X = Console.WindowLeft;')
    [void]$framework.AppendLine('                s.Y = Console.WindowTop;')
}
else {
    [void]$framework.AppendLine('                // Dummy-Wert für Winforms')
    [void]$framework.AppendLine('                s.X = 0;')
    [void]$framework.AppendLine('                s.Y = 0;')
}

[void]$framework.AppendLine('                return s;')
[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            set')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                Console.WindowLeft = value.X;')
    [void]$framework.AppendLine('                Console.WindowTop = value.Y;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override System.Management.Automation.Host.Size WindowSize')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                System.Management.Automation.Host.Size s = new System.Management.Automation.Host.Size();')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                s.Height = Console.WindowHeight;')
    [void]$framework.AppendLine('                s.Width = Console.WindowWidth;')
}
else {
    [void]$framework.AppendLine('                // Dummy-Wert für Winforms')
    [void]$framework.AppendLine('                s.Height = 50;')
    [void]$framework.AppendLine('                s.Width = 120;')
}

[void]$framework.AppendLine('                return s;')
[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            set')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                Console.WindowWidth = value.Width;')
    [void]$framework.AppendLine('                Console.WindowHeight = value.Height;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override string WindowTitle')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                return Console.Title;')
}
else {
    [void]$framework.AppendLine('                return System.AppDomain.CurrentDomain.FriendlyName;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            set')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                Console.Title = value;')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')
[void]$framework.AppendLine('    }')

#endregion

#region Graphical User Interface

if ($NoConsole) {
    [void]$framework.AppendLine()
    [void]$framework.AppendLine('    public class InputBox')
    [void]$framework.AppendLine('    {')
    [void]$framework.AppendLine('        [DllImport("user32.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]')
    [void]$framework.AppendLine('        private static extern IntPtr MB_GetString(uint strId);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public static DialogResult Show(string sTitle, string sPrompt, ref string sValue, bool bSecure)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            // Generate controls')
    [void]$framework.AppendLine('            Form form = new Form();')
    [void]$framework.AppendLine('            form.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);')
    [void]$framework.AppendLine('            form.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;')
    [void]$framework.AppendLine('            Label label = new Label();')
    [void]$framework.AppendLine('            TextBox textBox = new TextBox();')
    [void]$framework.AppendLine('            Button buttonOk = new Button();')
    [void]$framework.AppendLine('            Button buttonCancel = new Button();')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Sizes and positions are defined according to the label')
    [void]$framework.AppendLine('            // This control has to be finished first')
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(sPrompt))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                if (bSecure)')
    [void]$framework.AppendLine('                    label.Text = "Secure input:   ";')
    [void]$framework.AppendLine('                else')
    [void]$framework.AppendLine('                    label.Text = "Input:          ";')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                label.Text = sPrompt;')
    [void]$framework.AppendLine('            label.Location = new Point(9, 19);')
    [void]$framework.AppendLine('            label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);')
    [void]$framework.AppendLine('            label.AutoSize = true;')
    [void]$framework.AppendLine('            // Size of the label is defined not before Add()')
    [void]$framework.AppendLine('            form.Controls.Add(label);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Generate textbox')
    [void]$framework.AppendLine('            if (bSecure) textBox.UseSystemPasswordChar = true;')
    [void]$framework.AppendLine('            textBox.Text = sValue;')
    [void]$framework.AppendLine('            textBox.SetBounds(12, label.Bottom, label.Right - 12, 20);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Generate buttons')
    [void]$framework.AppendLine('            // get localized "OK"-string')
    [void]$framework.AppendLine('            string sTextOK = Marshal.PtrToStringUni(MB_GetString(0));')
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(sTextOK))')
    [void]$framework.AppendLine('                buttonOk.Text = "OK";')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                buttonOk.Text = sTextOK;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // get localized "Cancel"-string')
    [void]$framework.AppendLine('            string sTextCancel = Marshal.PtrToStringUni(MB_GetString(1));')
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(sTextCancel))')
    [void]$framework.AppendLine('                buttonCancel.Text = "Cancel";')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                buttonCancel.Text = sTextCancel;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            buttonOk.DialogResult = DialogResult.OK;')
    [void]$framework.AppendLine('            buttonCancel.DialogResult = DialogResult.Cancel;')
    [void]$framework.AppendLine('            buttonOk.SetBounds(System.Math.Max(12, label.Right - 158), label.Bottom + 36, 75, 23);')
    [void]$framework.AppendLine('            buttonCancel.SetBounds(System.Math.Max(93, label.Right - 77), label.Bottom + 36, 75, 23);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Configure form')
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(sTitle))')
    [void]$framework.AppendLine('                form.Text = System.AppDomain.CurrentDomain.FriendlyName;')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                form.Text = sTitle;')
    [void]$framework.AppendLine('            form.ClientSize = new System.Drawing.Size(System.Math.Max(178, label.Right + 10), label.Bottom + 71);')
    [void]$framework.AppendLine('            form.Controls.AddRange(new Control[] { textBox, buttonOk, buttonCancel });')
    [void]$framework.AppendLine('            form.FormBorderStyle = FormBorderStyle.FixedDialog;')
    [void]$framework.AppendLine('            form.StartPosition = FormStartPosition.CenterScreen;')
    [void]$framework.AppendLine('            try')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            catch')
    [void]$framework.AppendLine('            { }')
    [void]$framework.AppendLine('            form.MinimizeBox = false;')
    [void]$framework.AppendLine('            form.MaximizeBox = false;')
    [void]$framework.AppendLine('            form.AcceptButton = buttonOk;')
    [void]$framework.AppendLine('            form.CancelButton = buttonCancel;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Show form and compute results')
    [void]$framework.AppendLine('            DialogResult dialogResult = form.ShowDialog();')
    [void]$framework.AppendLine('            sValue = textBox.Text;')
    [void]$framework.AppendLine('            return dialogResult;')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public static DialogResult Show(string sTitle, string sPrompt, ref string sValue)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            return Show(sTitle, sPrompt, ref sValue, false);')
    [void]$framework.AppendLine('        }')
    [void]$framework.AppendLine('    }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('    public class ChoiceBox')
    [void]$framework.AppendLine('    {')
    [void]$framework.AppendLine('        public static int Show(System.Collections.ObjectModel.Collection<ChoiceDescription> aAuswahl, int iVorgabe, string sTitle, string sPrompt)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            // cancel if array is empty')
    [void]$framework.AppendLine('            if (aAuswahl == null) return -1;')
    [void]$framework.AppendLine('            if (aAuswahl.Count < 1) return -1;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Generate controls')
    [void]$framework.AppendLine('            Form form = new Form();')
    [void]$framework.AppendLine('            form.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);')
    [void]$framework.AppendLine('            form.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;')
    [void]$framework.AppendLine('            RadioButton[] aradioButton = new RadioButton[aAuswahl.Count];')
    [void]$framework.AppendLine('            ToolTip toolTip = new ToolTip();')
    [void]$framework.AppendLine('            Button buttonOk = new Button();')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Sizes and positions are defined according to the label')
    [void]$framework.AppendLine('            // This control has to be finished first when a prompt is available')
    [void]$framework.AppendLine('            int iPosY = 19, iMaxX = 0;')
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(sPrompt))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                Label label = new Label();')
    [void]$framework.AppendLine('                label.Text = sPrompt;')
    [void]$framework.AppendLine('                label.Location = new Point(9, 19);')
    [void]$framework.AppendLine('                label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);')
    [void]$framework.AppendLine('                label.AutoSize = true;')
    [void]$framework.AppendLine('                // erst durch Add() wird die Größe des Labels ermittelt')
    [void]$framework.AppendLine('                form.Controls.Add(label);')
    [void]$framework.AppendLine('                iPosY = label.Bottom;')
    [void]$framework.AppendLine('                iMaxX = label.Right;')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // An den Radiobuttons orientieren sich die weiteren Größen und Positionen')
    [void]$framework.AppendLine('            // Diese Controls also jetzt fertigstellen')
    [void]$framework.AppendLine('            int Counter = 0;')
    [void]$framework.AppendLine('            int tempWidth = System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18;')
    [void]$framework.AppendLine('            foreach (ChoiceDescription sAuswahl in aAuswahl)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                aradioButton[Counter] = new RadioButton();')
    [void]$framework.AppendLine('                aradioButton[Counter].Text = sAuswahl.Label;')
    [void]$framework.AppendLine('                if (Counter == iVorgabe)')
    [void]$framework.AppendLine('                    aradioButton[Counter].Checked = true;')
    [void]$framework.AppendLine('                aradioButton[Counter].Location = new Point(9, iPosY);')
    [void]$framework.AppendLine('                aradioButton[Counter].AutoSize = true;')
    [void]$framework.AppendLine('                // erst durch Add() wird die Größe des Labels ermittelt')
    [void]$framework.AppendLine('                form.Controls.Add(aradioButton[Counter]);')
    [void]$framework.AppendLine('                if (aradioButton[Counter].Width > tempWidth)')
    [void]$framework.AppendLine('                { // radio field to wide for screen -> make two lines')
    [void]$framework.AppendLine('                    int tempHeight = aradioButton[Counter].Height;')
    [void]$framework.AppendLine('                    aradioButton[Counter].Height = tempHeight * (1 + (aradioButton[Counter].Width - 1) / tempWidth);')
    [void]$framework.AppendLine('                    aradioButton[Counter].Width = tempWidth;')
    [void]$framework.AppendLine('                    aradioButton[Counter].AutoSize = false;')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('                iPosY = aradioButton[Counter].Bottom;')
    [void]$framework.AppendLine('                if (aradioButton[Counter].Right > iMaxX) { iMaxX = aradioButton[Counter].Right; }')
    [void]$framework.AppendLine('                if (!string.IsNullOrEmpty(sAuswahl.HelpMessage))')
    [void]$framework.AppendLine('                    toolTip.SetToolTip(aradioButton[Counter], sAuswahl.HelpMessage);')
    [void]$framework.AppendLine('                Counter++;')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Tooltip auch anzeigen, wenn Parent-Fenster inaktiv ist')
    [void]$framework.AppendLine('            toolTip.ShowAlways = true;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Button erzeugen')
    [void]$framework.AppendLine('            buttonOk.Text = "OK";')
    [void]$framework.AppendLine('            buttonOk.DialogResult = DialogResult.OK;')
    [void]$framework.AppendLine('            buttonOk.SetBounds(System.Math.Max(12, iMaxX - 77), iPosY + 36, 75, 23);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // configure form')
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(sTitle))')
    [void]$framework.AppendLine('                form.Text = System.AppDomain.CurrentDomain.FriendlyName;')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                form.Text = sTitle;')
    [void]$framework.AppendLine('            form.ClientSize = new System.Drawing.Size(System.Math.Max(178, iMaxX + 10), iPosY + 71);')
    [void]$framework.AppendLine('            form.Controls.Add(buttonOk);')
    [void]$framework.AppendLine('            form.FormBorderStyle = FormBorderStyle.FixedDialog;')
    [void]$framework.AppendLine('            form.StartPosition = FormStartPosition.CenterScreen;')
    [void]$framework.AppendLine('            try')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            catch')
    [void]$framework.AppendLine('            { }')
    [void]$framework.AppendLine('            form.MinimizeBox = false;')
    [void]$framework.AppendLine('            form.MaximizeBox = false;')
    [void]$framework.AppendLine('            form.AcceptButton = buttonOk;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // show and compute form')
    [void]$framework.AppendLine('            if (form.ShowDialog() == DialogResult.OK)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                int iRueck = -1;')
    [void]$framework.AppendLine('                for (Counter = 0; Counter < aAuswahl.Count; Counter++)')
    [void]$framework.AppendLine('                {')
    [void]$framework.AppendLine('                    if (aradioButton[Counter].Checked == true)')
    [void]$framework.AppendLine('                    { iRueck = Counter; }')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('                return iRueck;')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                return -1;')
    [void]$framework.AppendLine('        }')
    [void]$framework.AppendLine('    }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('    public class ReadKeyBox')
    [void]$framework.AppendLine('    {')
    [void]$framework.AppendLine('        [DllImport("user32.dll")]')
    [void]$framework.AppendLine('        public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState,')
    [void]$framework.AppendLine('            [Out, MarshalAs(UnmanagedType.LPWStr, SizeConst = 64)] System.Text.StringBuilder pwszBuff,')
    [void]$framework.AppendLine('            int cchBuff, uint wFlags);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        static string GetCharFromKeys(Keys keys, bool bShift, bool bAltGr)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            System.Text.StringBuilder buffer = new System.Text.StringBuilder(64);')
    [void]$framework.AppendLine('            byte[] keyboardState = new byte[256];')
    [void]$framework.AppendLine('            if (bShift)')
    [void]$framework.AppendLine('            { keyboardState[(int)Keys.ShiftKey] = 0xff; }')
    [void]$framework.AppendLine('            if (bAltGr)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                keyboardState[(int)Keys.ControlKey] = 0xff;')
    [void]$framework.AppendLine('                keyboardState[(int)Keys.Menu] = 0xff;')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            if (ToUnicode((uint) keys, 0, keyboardState, buffer, 64, 0) >= 1)')
    [void]$framework.AppendLine('                return buffer.ToString();')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                return "\0";')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        class KeyboardForm : Form')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            public KeyboardForm()')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);')
    [void]$framework.AppendLine('                this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;')
    [void]$framework.AppendLine('                this.KeyDown += new KeyEventHandler(KeyboardForm_KeyDown);')
    [void]$framework.AppendLine('                this.KeyUp += new KeyEventHandler(KeyboardForm_KeyUp);')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // check for KeyDown or KeyUp?')
    [void]$framework.AppendLine('            public bool checkKeyDown = true;')
    [void]$framework.AppendLine('            // key code for pressed key')
    [void]$framework.AppendLine('            public KeyInfo keyinfo;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            void KeyboardForm_KeyDown(object sender, KeyEventArgs e)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                if (checkKeyDown)')
    [void]$framework.AppendLine('                { // store key info')
    [void]$framework.AppendLine('                    keyinfo.VirtualKeyCode = e.KeyValue;')
    [void]$framework.AppendLine('                    keyinfo.Character = GetCharFromKeys(e.KeyCode, e.Shift, e.Alt & e.Control)[0];')
    [void]$framework.AppendLine('                    keyinfo.KeyDown = false;')
    [void]$framework.AppendLine('                    keyinfo.ControlKeyState = 0;')
    [void]$framework.AppendLine('                    if (e.Alt) { keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed; }')
    [void]$framework.AppendLine('                    if (e.Control)')
    [void]$framework.AppendLine('                    {')
    [void]$framework.AppendLine('                        keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;')
    [void]$framework.AppendLine('                        if (!e.Alt)')
    [void]$framework.AppendLine('                        { if (e.KeyValue > 64 && e.KeyValue < 96) keyinfo.Character = (char)(e.KeyValue - 64); }')
    [void]$framework.AppendLine('                    }')
    [void]$framework.AppendLine('                    if (e.Shift) { keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed; }')
    [void]$framework.AppendLine('                    if ((e.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn; }')
    [void]$framework.AppendLine('                    if ((e.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn; }')
    [void]$framework.AppendLine('                    // and close the form')
    [void]$framework.AppendLine('                    this.Close();')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            void KeyboardForm_KeyUp(object sender, KeyEventArgs e)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                if (!checkKeyDown)')
    [void]$framework.AppendLine('                { // store key info')
    [void]$framework.AppendLine('                    keyinfo.VirtualKeyCode = e.KeyValue;')
    [void]$framework.AppendLine('                    keyinfo.Character = GetCharFromKeys(e.KeyCode, e.Shift, e.Alt & e.Control)[0];')
    [void]$framework.AppendLine('                    keyinfo.KeyDown = true;')
    [void]$framework.AppendLine('                    keyinfo.ControlKeyState = 0;')
    [void]$framework.AppendLine('                    if (e.Alt) { keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed; }')
    [void]$framework.AppendLine('                    if (e.Control)')
    [void]$framework.AppendLine('                    {')
    [void]$framework.AppendLine('                        keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;')
    [void]$framework.AppendLine('                        if (!e.Alt)')
    [void]$framework.AppendLine('                        { if (e.KeyValue > 64 && e.KeyValue < 96) keyinfo.Character = (char)(e.KeyValue - 64); }')
    [void]$framework.AppendLine('                    }')
    [void]$framework.AppendLine('                    if (e.Shift) { keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed; }')
    [void]$framework.AppendLine('                    if ((e.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn; }')
    [void]$framework.AppendLine('                    if ((e.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn; }')
    [void]$framework.AppendLine('                    // and close the form')
    [void]$framework.AppendLine('                    this.Close();')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public static KeyInfo Show(string sTitle, string sPrompt, bool bIncludeKeyDown)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            // Controls erzeugen')
    [void]$framework.AppendLine('            KeyboardForm form = new KeyboardForm();')
    [void]$framework.AppendLine('            Label label = new Label();')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Am Label orientieren sich die Größen und Positionen')
    [void]$framework.AppendLine('            // Dieses Control also zuerst fertigstellen')
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(sPrompt))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                label.Text = "Press a key";')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                label.Text = sPrompt;')
    [void]$framework.AppendLine('            label.Location = new Point(9, 19);')
    [void]$framework.AppendLine('            label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);')
    [void]$framework.AppendLine('            label.AutoSize = true;')
    [void]$framework.AppendLine('            // erst durch Add() wird die Größe des Labels ermittelt')
    [void]$framework.AppendLine('            form.Controls.Add(label);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // configure form')
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(sTitle))')
    [void]$framework.AppendLine('                form.Text = System.AppDomain.CurrentDomain.FriendlyName;')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                form.Text = sTitle;')
    [void]$framework.AppendLine('            form.ClientSize = new System.Drawing.Size(System.Math.Max(178, label.Right + 10), label.Bottom + 55);')
    [void]$framework.AppendLine('            form.FormBorderStyle = FormBorderStyle.FixedDialog;')
    [void]$framework.AppendLine('            form.StartPosition = FormStartPosition.CenterScreen;')
    [void]$framework.AppendLine('            try')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            catch')
    [void]$framework.AppendLine('            { }')
    [void]$framework.AppendLine('            form.MinimizeBox = false;')
    [void]$framework.AppendLine('            form.MaximizeBox = false;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // show and compute form')
    [void]$framework.AppendLine('            form.checkKeyDown = bIncludeKeyDown;')
    [void]$framework.AppendLine('            form.ShowDialog();')
    [void]$framework.AppendLine('            return form.keyinfo;')
    [void]$framework.AppendLine('        }')
    [void]$framework.AppendLine('    }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('    public class ProgressForm : Form')
    [void]$framework.AppendLine('    {')
    [void]$framework.AppendLine('        private Label objLblActivity;')
    [void]$framework.AppendLine('        private Label objLblStatus;')
    [void]$framework.AppendLine('        private ProgressBar objProgressBar;')
    [void]$framework.AppendLine('        private Label objLblRemainingTime;')
    [void]$framework.AppendLine('        private Label objLblOperation;')
    [void]$framework.AppendLine('        private ConsoleColor ProgressBarColor = ConsoleColor.DarkCyan;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        private Color DrawingColor(ConsoleColor color)')
    [void]$framework.AppendLine('        {  // convert ConsoleColor to System.Drawing.Color')
    [void]$framework.AppendLine('            switch (color)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                case ConsoleColor.Black: return Color.Black;')
    [void]$framework.AppendLine('                case ConsoleColor.Blue: return Color.Blue;')
    [void]$framework.AppendLine('                case ConsoleColor.Cyan: return Color.Cyan;')
    [void]$framework.AppendLine('                case ConsoleColor.DarkBlue: return ColorTranslator.FromHtml("#000080");')
    [void]$framework.AppendLine('                case ConsoleColor.DarkGray: return ColorTranslator.FromHtml("#808080");')
    [void]$framework.AppendLine('                case ConsoleColor.DarkGreen: return ColorTranslator.FromHtml("#008000");')
    [void]$framework.AppendLine('                case ConsoleColor.DarkCyan: return ColorTranslator.FromHtml("#008080");')
    [void]$framework.AppendLine('                case ConsoleColor.DarkMagenta: return ColorTranslator.FromHtml("#800080");')
    [void]$framework.AppendLine('                case ConsoleColor.DarkRed: return ColorTranslator.FromHtml("#800000");')
    [void]$framework.AppendLine('                case ConsoleColor.DarkYellow: return ColorTranslator.FromHtml("#808000");')
    [void]$framework.AppendLine('                case ConsoleColor.Gray: return ColorTranslator.FromHtml("#C0C0C0");')
    [void]$framework.AppendLine('                case ConsoleColor.Green: return ColorTranslator.FromHtml("#00FF00");')
    [void]$framework.AppendLine('                case ConsoleColor.Magenta: return Color.Magenta;')
    [void]$framework.AppendLine('                case ConsoleColor.Red: return Color.Red;')
    [void]$framework.AppendLine('                case ConsoleColor.White: return Color.White;')
    [void]$framework.AppendLine('                default: return Color.Yellow;')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        private void InitializeComponent()')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            this.SuspendLayout();')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);')
    [void]$framework.AppendLine('            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            this.Text = "Progress";')
    [void]$framework.AppendLine('            this.Height = 160;')
    [void]$framework.AppendLine('            this.Width = 800;')
    [void]$framework.AppendLine('            this.BackColor = Color.White;')
    [void]$framework.AppendLine('            this.FormBorderStyle = FormBorderStyle.FixedSingle;')
    [void]$framework.AppendLine('            try')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                this.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            catch')
    [void]$framework.AppendLine('            { }')
    [void]$framework.AppendLine('            this.MinimizeBox = false;')
    [void]$framework.AppendLine('            this.MaximizeBox = false;')
    [void]$framework.AppendLine('            this.StartPosition = FormStartPosition.CenterScreen;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Create Label')
    [void]$framework.AppendLine('            objLblActivity = new Label();')
    [void]$framework.AppendLine('            objLblActivity.Left = 5;')
    [void]$framework.AppendLine('            objLblActivity.Top = 10;')
    [void]$framework.AppendLine('            objLblActivity.Width = 800 - 20;')
    [void]$framework.AppendLine('            objLblActivity.Height = 16;')
    [void]$framework.AppendLine('            objLblActivity.Font = new Font(objLblActivity.Font, FontStyle.Bold);')
    [void]$framework.AppendLine('            objLblActivity.Text = "";')
    [void]$framework.AppendLine('            // Add Label to Form')
    [void]$framework.AppendLine('            this.Controls.Add(objLblActivity);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Create Label')
    [void]$framework.AppendLine('            objLblStatus = new Label();')
    [void]$framework.AppendLine('            objLblStatus.Left = 25;')
    [void]$framework.AppendLine('            objLblStatus.Top = 26;')
    [void]$framework.AppendLine('            objLblStatus.Width = 800 - 40;')
    [void]$framework.AppendLine('            objLblStatus.Height = 16;')
    [void]$framework.AppendLine('            objLblStatus.Text = "";')
    [void]$framework.AppendLine('            // Add Label to Form')
    [void]$framework.AppendLine('            this.Controls.Add(objLblStatus);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Create ProgressBar')
    [void]$framework.AppendLine('            objProgressBar = new ProgressBar();')
    [void]$framework.AppendLine('            objProgressBar.Value = 0;')
    [void]$framework.AppendLine('            objProgressBar.Style = ProgressBarStyle.Continuous;')
    [void]$framework.AppendLine('            objProgressBar.ForeColor = DrawingColor(ProgressBarColor);')
    [void]$framework.AppendLine('            objProgressBar.Size = new System.Drawing.Size(800 - 60, 20);')
    [void]$framework.AppendLine('            objProgressBar.Left = 25;')
    [void]$framework.AppendLine('            objProgressBar.Top = 55;')
    [void]$framework.AppendLine('            // Add ProgressBar to Form')
    [void]$framework.AppendLine('            this.Controls.Add(objProgressBar);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Create Label')
    [void]$framework.AppendLine('            objLblRemainingTime = new Label();')
    [void]$framework.AppendLine('            objLblRemainingTime.Left = 5;')
    [void]$framework.AppendLine('            objLblRemainingTime.Top = 85;')
    [void]$framework.AppendLine('            objLblRemainingTime.Width = 800 - 20;')
    [void]$framework.AppendLine('            objLblRemainingTime.Height = 16;')
    [void]$framework.AppendLine('            objLblRemainingTime.Text = "";')
    [void]$framework.AppendLine('            // Add Label to Form')
    [void]$framework.AppendLine('            this.Controls.Add(objLblRemainingTime);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Create Label')
    [void]$framework.AppendLine('            objLblOperation = new Label();')
    [void]$framework.AppendLine('            objLblOperation.Left = 25;')
    [void]$framework.AppendLine('            objLblOperation.Top = 101;')
    [void]$framework.AppendLine('            objLblOperation.Width = 800 - 40;')
    [void]$framework.AppendLine('            objLblOperation.Height = 16;')
    [void]$framework.AppendLine('            objLblOperation.Text = "";')
    [void]$framework.AppendLine('            // Add Label to Form')
    [void]$framework.AppendLine('            this.Controls.Add(objLblOperation);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            this.ResumeLayout();')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public ProgressForm()')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            InitializeComponent();')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public ProgressForm(ConsoleColor BarColor)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            ProgressBarColor = BarColor;')
    [void]$framework.AppendLine('            InitializeComponent();')
    [void]$framework.AppendLine('        }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public void Update(ProgressRecord objRecord)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            if (objRecord == null)')
    [void]$framework.AppendLine('                return;')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (objRecord.RecordType == ProgressRecordType.Completed)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                this.Close();')
    [void]$framework.AppendLine('                return;')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(objRecord.Activity))')
    [void]$framework.AppendLine('                objLblActivity.Text = objRecord.Activity;')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                objLblActivity.Text = "";')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(objRecord.StatusDescription))')
    [void]$framework.AppendLine('                objLblStatus.Text = objRecord.StatusDescription;')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                objLblStatus.Text = "";')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if ((objRecord.PercentComplete >= 0) && (objRecord.PercentComplete <= 100))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                objProgressBar.Value = objRecord.PercentComplete;')
    [void]$framework.AppendLine('                objProgressBar.Visible = true;')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                if (objRecord.PercentComplete > 100)')
    [void]$framework.AppendLine('                {')
    [void]$framework.AppendLine('                    objProgressBar.Value = 0;')
    [void]$framework.AppendLine('                    objProgressBar.Visible = true;')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('                else')
    [void]$framework.AppendLine('                    objProgressBar.Visible = false;')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (objRecord.SecondsRemaining >= 0)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                System.TimeSpan objTimeSpan = new System.TimeSpan(0, 0, objRecord.SecondsRemaining);')
    [void]$framework.AppendLine('                objLblRemainingTime.Text = "Remaining time: " + string.Format("{0:00}:{1:00}:{2:00}", (int)objTimeSpan.TotalHours, objTimeSpan.Minutes, objTimeSpan.Seconds);')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                objLblRemainingTime.Text = "";')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(objRecord.CurrentOperation))')
    [void]$framework.AppendLine('                objLblOperation.Text = objRecord.CurrentOperation;')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                objLblOperation.Text = "";')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            this.Refresh();')
    [void]$framework.AppendLine('            Application.DoEvents();')
    [void]$framework.AppendLine('        }')
    [void]$framework.AppendLine('    }')
}

#endregion

#region Redirects

[void]$framework.AppendLine()
[void]$framework.AppendLine('    // define IsInputRedirected(), IsOutputRedirected() and IsErrorRedirected() here since they were introduced first with .Net 4.5')
[void]$framework.AppendLine('    public class ConsoleInfo')
[void]$framework.AppendLine('    {')
[void]$framework.AppendLine('        private enum FileType : uint')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            FILE_TYPE_UNKNOWN = 0x0000,')
[void]$framework.AppendLine('            FILE_TYPE_DISK = 0x0001,')
[void]$framework.AppendLine('            FILE_TYPE_CHAR = 0x0002,')
[void]$framework.AppendLine('            FILE_TYPE_PIPE = 0x0003,')
[void]$framework.AppendLine('            FILE_TYPE_REMOTE = 0x8000')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        private enum STDHandle : uint')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            STD_INPUT_HANDLE = unchecked((uint)-10),')
[void]$framework.AppendLine('            STD_OUTPUT_HANDLE = unchecked((uint)-11),')
[void]$framework.AppendLine('            STD_ERROR_HANDLE = unchecked((uint)-12)')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        [DllImport("kernel32.dll")]')
[void]$framework.AppendLine('        static private extern UIntPtr GetStdHandle(STDHandle stdHandle);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        [DllImport("kernel32.dll")]')
[void]$framework.AppendLine('        static private extern FileType GetFileType(UIntPtr hFile);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        static public bool IsInputRedirected()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            UIntPtr hInput = GetStdHandle(STDHandle.STD_INPUT_HANDLE);')
[void]$framework.AppendLine('            FileType fileType = (FileType)GetFileType(hInput);')
[void]$framework.AppendLine('            if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))')
[void]$framework.AppendLine('                return false;')
[void]$framework.AppendLine('            return true;')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        static public bool IsOutputRedirected()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            UIntPtr hOutput = GetStdHandle(STDHandle.STD_OUTPUT_HANDLE);')
[void]$framework.AppendLine('            FileType fileType = (FileType)GetFileType(hOutput);')
[void]$framework.AppendLine('            if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))')
[void]$framework.AppendLine('                return false;')
[void]$framework.AppendLine('            return true;')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        static public bool IsErrorRedirected()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            UIntPtr hError = GetStdHandle(STDHandle.STD_ERROR_HANDLE);')
[void]$framework.AppendLine('            FileType fileType = (FileType)GetFileType(hError);')
[void]$framework.AppendLine('            if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))')
[void]$framework.AppendLine('                return false;')
[void]$framework.AppendLine('            return true;')
[void]$framework.AppendLine('        }')
[void]$framework.AppendLine('    }')

#endregion

#region PS2EXE Host User Interface

[void]$framework.AppendLine()
[void]$framework.AppendLine('    internal class PS2EXEHostUI : PSHostUserInterface')
[void]$framework.AppendLine('    {')
[void]$framework.AppendLine('        private PS2EXEHostRawUI rawUI = null;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public ConsoleColor ErrorForegroundColor = ConsoleColor.Red;')
[void]$framework.AppendLine('        public ConsoleColor ErrorBackgroundColor = ConsoleColor.Black;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public ConsoleColor WarningForegroundColor = ConsoleColor.Yellow;')
[void]$framework.AppendLine('        public ConsoleColor WarningBackgroundColor = ConsoleColor.Black;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public ConsoleColor DebugForegroundColor = ConsoleColor.Yellow;')
[void]$framework.AppendLine('        public ConsoleColor DebugBackgroundColor = ConsoleColor.Black;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public ConsoleColor VerboseForegroundColor = ConsoleColor.Yellow;')
[void]$framework.AppendLine('        public ConsoleColor VerboseBackgroundColor = ConsoleColor.Black;')

if (-not $NoConsole) {
    [void]$framework.AppendLine('        public ConsoleColor ProgressForegroundColor = ConsoleColor.Yellow;')
}
else {
    [void]$framework.AppendLine('        public ConsoleColor ProgressForegroundColor = ConsoleColor.DarkCyan;')
}

[void]$framework.AppendLine('        public ConsoleColor ProgressBackgroundColor = ConsoleColor.DarkCyan;')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public PS2EXEHostUI() : base()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            rawUI = new PS2EXEHostRawUI();')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            rawUI.ForegroundColor = Console.ForegroundColor;')
    [void]$framework.AppendLine('            rawUI.BackgroundColor = Console.BackgroundColor;')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override Dictionary<string, PSObject> Prompt(string caption, string message, System.Collections.ObjectModel.Collection<FieldDescription> descriptions)')
[void]$framework.AppendLine('        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(caption)) WriteLine(caption);')
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(message)) WriteLine(message);')
}
else {
    [void]$framework.AppendLine('            if ((!string.IsNullOrEmpty(caption)) || (!string.IsNullOrEmpty(message)))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                string sTitel = System.AppDomain.CurrentDomain.FriendlyName, sMeldung = "";')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('                if (!string.IsNullOrEmpty(caption)) sTitel = caption;')
    [void]$framework.AppendLine('                if (!string.IsNullOrEmpty(message)) sMeldung = message;')
    [void]$framework.AppendLine('                MessageBox.Show(sMeldung, sTitel);')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            // Titel und Labeltext für Inputbox zurücksetzen')
    [void]$framework.AppendLine('            ibcaption = "";')
    [void]$framework.AppendLine('            ibmessage = "";')
}

[void]$framework.AppendLine('            Dictionary<string, PSObject> ret = new Dictionary<string, PSObject>();')
[void]$framework.AppendLine('            foreach (FieldDescription cd in descriptions)')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                Type t = null;')
[void]$framework.AppendLine('                if (string.IsNullOrEmpty(cd.ParameterAssemblyFullName))')
[void]$framework.AppendLine('                    t = typeof(string);')
[void]$framework.AppendLine('                else')
[void]$framework.AppendLine('                    t = Type.GetType(cd.ParameterAssemblyFullName);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                if (t.IsArray)')
[void]$framework.AppendLine('                {')
[void]$framework.AppendLine('                    Type elementType = t.GetElementType();')
[void]$framework.AppendLine('                    Type genericListType = Type.GetType("System.Collections.Generic.List" + ((char)0x60).ToString() + "1");')
[void]$framework.AppendLine('                    genericListType = genericListType.MakeGenericType(new Type[] { elementType });')
[void]$framework.AppendLine('                    ConstructorInfo constructor = genericListType.GetConstructor(BindingFlags.CreateInstance | BindingFlags.Instance | BindingFlags.Public, null, Type.EmptyTypes, null);')
[void]$framework.AppendLine('                    object resultList = constructor.Invoke(null);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                    int index = 0;')
[void]$framework.AppendLine('                    string data = "";')
[void]$framework.AppendLine('                    do')
[void]$framework.AppendLine('                    {')
[void]$framework.AppendLine('                        try')
[void]$framework.AppendLine('                        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                            if (!string.IsNullOrEmpty(cd.Name)) Write(string.Format("{0}[{1}]: ", cd.Name, index));')
}
else {
    [void]$framework.AppendLine('                            if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}[{1}]: ", cd.Name, index);')
}

[void]$framework.AppendLine('                            data = ReadLine();')
[void]$framework.AppendLine('                            if (string.IsNullOrEmpty(data))')
[void]$framework.AppendLine('                                break;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                            object o = System.Convert.ChangeType(data, elementType);')
[void]$framework.AppendLine('                            genericListType.InvokeMember("Add", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, new object[] { o });')
[void]$framework.AppendLine('                        }')
[void]$framework.AppendLine('                        catch (Exception e)')
[void]$framework.AppendLine('                        {')
[void]$framework.AppendLine('                            throw e;')
[void]$framework.AppendLine('                        }')
[void]$framework.AppendLine('                        index++;')
[void]$framework.AppendLine('                    } while (true);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                    System.Array retArray = (System.Array)genericListType.InvokeMember("ToArray", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, null);')
[void]$framework.AppendLine('                    ret.Add(cd.Name, new PSObject(retArray));')
[void]$framework.AppendLine('                }')
[void]$framework.AppendLine('                else')
[void]$framework.AppendLine('                {')
[void]$framework.AppendLine('                    object o = null;')
[void]$framework.AppendLine('                    string l = null;')
[void]$framework.AppendLine('                    try')
[void]$framework.AppendLine('                    {')
[void]$framework.AppendLine('                        if (t != typeof(System.Security.SecureString))')
[void]$framework.AppendLine('                        {')
[void]$framework.AppendLine('                            if (t != typeof(System.Management.Automation.PSCredential))')
[void]$framework.AppendLine('                            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                                if (!string.IsNullOrEmpty(cd.Name)) Write(cd.Name);')
    [void]$framework.AppendLine('                                if (!string.IsNullOrEmpty(cd.HelpMessage)) Write(" (Type !? for help.)");')
    [void]$framework.AppendLine('                                if ((!string.IsNullOrEmpty(cd.Name)) || (!string.IsNullOrEmpty(cd.HelpMessage))) Write(": ");')
}
else {
    [void]$framework.AppendLine('                                if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}: ", cd.Name);')
    [void]$framework.AppendLine('                                if (!string.IsNullOrEmpty(cd.HelpMessage)) ibmessage += "\n(Type !? for help.)";')
}

[void]$framework.AppendLine('                                do')
[void]$framework.AppendLine('                                {')
[void]$framework.AppendLine('                                    l = ReadLine();')
[void]$framework.AppendLine('                                    if (l == "!?")')
[void]$framework.AppendLine('                                    {')
[void]$framework.AppendLine('                                        WriteLine(cd.HelpMessage);')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                                        if (!string.IsNullOrEmpty(cd.Name)) Write(cd.Name);')
    [void]$framework.AppendLine('                                        if (!string.IsNullOrEmpty(cd.HelpMessage)) Write(" (Type !? for help.)");')
    [void]$framework.AppendLine('                                        if ((!string.IsNullOrEmpty(cd.Name)) || (!string.IsNullOrEmpty(cd.HelpMessage))) Write(": ");')
}

[void]$framework.AppendLine('                                        l = "!?";')
[void]$framework.AppendLine('                                    }')
[void]$framework.AppendLine('                                    else')
[void]$framework.AppendLine('                                    {')
[void]$framework.AppendLine('                                        if (string.IsNullOrEmpty(l)) o = cd.DefaultValue;')
[void]$framework.AppendLine('                                        if (o == null)')
[void]$framework.AppendLine('                                        {')
[void]$framework.AppendLine('                                            try')
[void]$framework.AppendLine('                                            {')
[void]$framework.AppendLine('                                                o = System.Convert.ChangeType(l, t);')
[void]$framework.AppendLine('                                            }')
[void]$framework.AppendLine('                                            catch')
[void]$framework.AppendLine('                                            {')
[void]$framework.AppendLine('                                                Write("Wrong format, please repeat input: ");')
[void]$framework.AppendLine('                                                l = "!?";')
[void]$framework.AppendLine('                                            }')
[void]$framework.AppendLine('                                        }')
[void]$framework.AppendLine('                                    }')
[void]$framework.AppendLine('                                } while (l == "!?");')
[void]$framework.AppendLine('                            }')
[void]$framework.AppendLine('                            else')
[void]$framework.AppendLine('                            {')
[void]$framework.AppendLine('                                PSCredential pscred = PromptForCredential("", "", "", "");')
[void]$framework.AppendLine('                                o = pscred;')
[void]$framework.AppendLine('                            }')
[void]$framework.AppendLine('                        }')
[void]$framework.AppendLine('                        else')
[void]$framework.AppendLine('                        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                            if (!string.IsNullOrEmpty(cd.Name)) Write(string.Format("{0}: ", cd.Name));')
}
else {
    [void]$framework.AppendLine('                            if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}: ", cd.Name);')
}

[void]$framework.AppendLine()
[void]$framework.AppendLine('                            SecureString pwd = null;')
[void]$framework.AppendLine('                            pwd = ReadLineAsSecureString();')
[void]$framework.AppendLine('                            o = pwd;')
[void]$framework.AppendLine('                        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        ret.Add(cd.Name, new PSObject(o));')
[void]$framework.AppendLine('                    }')
[void]$framework.AppendLine('                    catch (Exception e)')
[void]$framework.AppendLine('                    {')
[void]$framework.AppendLine('                        throw e;')
[void]$framework.AppendLine('                    }')
[void]$framework.AppendLine('                }')
[void]$framework.AppendLine('            }')

if ($NoConsole) {
    [void]$framework.AppendLine('            // Titel und Labeltext für Inputbox zurücksetzen')
    [void]$framework.AppendLine('            ibcaption = "";')
    [void]$framework.AppendLine('            ibmessage = "";')
}

[void]$framework.AppendLine('            return ret;')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override int PromptForChoice(string caption, string message, System.Collections.ObjectModel.Collection<ChoiceDescription> choices, int defaultChoice)')
[void]$framework.AppendLine('        {')

if ($NoConsole) {
    [void]$framework.AppendLine('            int iReturn = ChoiceBox.Show(choices, defaultChoice, caption, message);')
    [void]$framework.AppendLine('            if (iReturn == -1) { iReturn = defaultChoice; }')
    [void]$framework.AppendLine('            return iReturn;')
}
else {
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(caption))')
    [void]$framework.AppendLine('                WriteLine(caption);')
    [void]$framework.AppendLine('            WriteLine(message);')
    [void]$framework.AppendLine('            int idx = 0;')
    [void]$framework.AppendLine('            SortedList<string, int> res = new SortedList<string, int>();')
    [void]$framework.AppendLine('            foreach (ChoiceDescription cd in choices)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                string lkey = cd.Label.Substring(0, 1), ltext = cd.Label;')
    [void]$framework.AppendLine('                int pos = cd.Label.IndexOf(''&'');')
    [void]$framework.AppendLine('                if (pos > -1)')
    [void]$framework.AppendLine('                {')
    [void]$framework.AppendLine('                    lkey = cd.Label.Substring(pos + 1, 1).ToUpper();')
    [void]$framework.AppendLine('                    if (pos > 0)')
    [void]$framework.AppendLine('                        ltext = cd.Label.Substring(0, pos) + cd.Label.Substring(pos + 1);')
    [void]$framework.AppendLine('                    else')
    [void]$framework.AppendLine('                        ltext = cd.Label.Substring(1);')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('                res.Add(lkey.ToLower(), idx);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('                if (idx > 0) Write("  ");')
    [void]$framework.AppendLine('                if (idx == defaultChoice)')
    [void]$framework.AppendLine('                {')
    [void]$framework.AppendLine('                    Write(ConsoleColor.Yellow, Console.BackgroundColor, string.Format("[{0}] {1}", lkey, ltext));')
    [void]$framework.AppendLine('                    if (!string.IsNullOrEmpty(cd.HelpMessage))')
    [void]$framework.AppendLine('                        Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format(" ({0})", cd.HelpMessage));')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('                else')
    [void]$framework.AppendLine('                {')
    [void]$framework.AppendLine('                    Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format("[{0}] {1}", lkey, ltext));')
    [void]$framework.AppendLine('                    if (!string.IsNullOrEmpty(cd.HelpMessage))')
    [void]$framework.AppendLine('                        Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format(" ({0})", cd.HelpMessage));')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('                idx++;')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            Write(": ");')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            try')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                while (true)')
    [void]$framework.AppendLine('                {')
    [void]$framework.AppendLine('                    string s = Console.ReadLine().ToLower();')
    [void]$framework.AppendLine('                    if (res.ContainsKey(s))')
    [void]$framework.AppendLine('                        return res[s];')
    [void]$framework.AppendLine('                    if (string.IsNullOrEmpty(s))')
    [void]$framework.AppendLine('                        return defaultChoice;')
    [void]$framework.AppendLine('                }')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            catch { }')
    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            return defaultChoice;')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)')
[void]$framework.AppendLine('        {')

if ((-not $NoConsole) -and (-not $CredentialGui)) {
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(caption)) WriteLine(caption);')
    [void]$framework.AppendLine('            WriteLine(message);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            string un;')
    [void]$framework.AppendLine('            if ((string.IsNullOrEmpty(userName)) || ((options & PSCredentialUIOptions.ReadOnlyUserName) == 0))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                Write("User name: ");')
    [void]$framework.AppendLine('                un = ReadLine();')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                Write("User name: ");')
    [void]$framework.AppendLine('                if (!string.IsNullOrEmpty(targetName)) Write(targetName + "\\");')
    [void]$framework.AppendLine('                WriteLine(userName);')
    [void]$framework.AppendLine('                un = userName;')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            SecureString pwd = null;')
    [void]$framework.AppendLine('            Write("Password: ");')
    [void]$framework.AppendLine('            pwd = ReadLineAsSecureString();')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(un)) un = "<NOUSER>";')
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(targetName))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                if (un.IndexOf(''\\'') < 0)')
    [void]$framework.AppendLine('                    un = targetName + "\\" + un;')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            PSCredential c2 = new PSCredential(un, pwd);')
    [void]$framework.AppendLine('            return c2;')
}
else {
    [void]$framework.AppendLine('            ik.PowerShell.CredentialForm.UserPwd cred = CredentialForm.PromptForPassword(caption, message, targetName, userName, allowedCredentialTypes, options);')
    [void]$framework.AppendLine('            if (cred != null)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                System.Security.SecureString x = new System.Security.SecureString();')
    [void]$framework.AppendLine('                foreach (char c in cred.Password.ToCharArray())')
    [void]$framework.AppendLine('                    x.AppendChar(c);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('                return new PSCredential(cred.User, x);')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            return null;')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)')
[void]$framework.AppendLine('        {')

if ((-not $NoConsole) -and (-not $CredentialGui)) {
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(caption)) WriteLine(caption);')
    [void]$framework.AppendLine('            WriteLine(message);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            string un;')
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(userName))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                Write("User name: ");')
    [void]$framework.AppendLine('                un = ReadLine();')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                Write("User name: ");')
    [void]$framework.AppendLine('                if (!string.IsNullOrEmpty(targetName)) Write(targetName + "\\");')
    [void]$framework.AppendLine('                WriteLine(userName);')
    [void]$framework.AppendLine('                un = userName;')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            SecureString pwd = null;')
    [void]$framework.AppendLine('            Write("Password: ");')
    [void]$framework.AppendLine('            pwd = ReadLineAsSecureString();')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (string.IsNullOrEmpty(un)) un = "<NOUSER>";')
    [void]$framework.AppendLine('            if (!string.IsNullOrEmpty(targetName))')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                if (un.IndexOf(''\\'') < 0)')
    [void]$framework.AppendLine('                    un = targetName + "\\" + un;')
    [void]$framework.AppendLine('            }')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            PSCredential c2 = new PSCredential(un, pwd);')
    [void]$framework.AppendLine('            return c2;')
}
else {
    [void]$framework.AppendLine('            ik.PowerShell.CredentialForm.UserPwd cred = CredentialForm.PromptForPassword(caption, message, targetName, userName, PSCredentialTypes.Default, PSCredentialUIOptions.Default);')
    [void]$framework.AppendLine('            if (cred != null)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                System.Security.SecureString x = new System.Security.SecureString();')
    [void]$framework.AppendLine('                foreach (char c in cred.Password.ToCharArray())')
    [void]$framework.AppendLine('                    x.AppendChar(c);')

    [void]$framework.AppendLine()
    [void]$framework.AppendLine('                return new PSCredential(cred.User, x);')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            return null;')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override PSHostRawUserInterface RawUI')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                return rawUI;')
[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')
[void]$framework.AppendLine()

if ($NoConsole) {
    [void]$framework.AppendLine('        private string ibcaption;')
    [void]$framework.AppendLine('        private string ibmessage;')
}

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override string ReadLine()')
[void]$framework.AppendLine('        {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            return Console.ReadLine();')
}
else {
    [void]$framework.AppendLine('            string sWert = "";')
    [void]$framework.AppendLine('            if (InputBox.Show(ibcaption, ibmessage, ref sWert) == DialogResult.OK)')
    [void]$framework.AppendLine('                return sWert;')
    [void]$framework.AppendLine('            else')
    [void]$framework.AppendLine('                return "";')
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        private System.Security.SecureString getPassword()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            System.Security.SecureString pwd = new System.Security.SecureString();')
[void]$framework.AppendLine('            while (true)')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                ConsoleKeyInfo i = Console.ReadKey(true);')
[void]$framework.AppendLine('                if (i.Key == ConsoleKey.Enter)')
[void]$framework.AppendLine('                {')
[void]$framework.AppendLine('                    Console.WriteLine();')
[void]$framework.AppendLine('                    break;')
[void]$framework.AppendLine('                }')
[void]$framework.AppendLine('                else if (i.Key == ConsoleKey.Backspace)')
[void]$framework.AppendLine('                {')
[void]$framework.AppendLine('                    if (pwd.Length > 0)')
[void]$framework.AppendLine('                    {')
[void]$framework.AppendLine('                        pwd.RemoveAt(pwd.Length - 1);')
[void]$framework.AppendLine('                        Console.Write("\b \b");')
[void]$framework.AppendLine('                    }')
[void]$framework.AppendLine('                }')
[void]$framework.AppendLine('                else if (i.KeyChar != ''\u0000'')')
[void]$framework.AppendLine('                {')
[void]$framework.AppendLine('                    pwd.AppendChar(i.KeyChar);')
[void]$framework.AppendLine('                    Console.Write("*");')
[void]$framework.AppendLine('                }')
[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            return pwd;')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override System.Security.SecureString ReadLineAsSecureString()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            System.Security.SecureString secstr = new System.Security.SecureString();')

if (-not $NoConsole) {
    [void]$framework.AppendLine('            secstr = getPassword();')
}
else {
    [void]$framework.AppendLine('            string sWert = "";')
    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            if (InputBox.Show(ibcaption, ibmessage, ref sWert, true) == DialogResult.OK)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                foreach (char ch in sWert)')
    [void]$framework.AppendLine('                    secstr.AppendChar(ch);')
    [void]$framework.AppendLine('            }')
}

[void]$framework.AppendLine('            return secstr;')
[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        // called by Write-Host')
[void]$framework.AppendLine('        public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)')
[void]$framework.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;')
        [void]$framework.AppendLine('            Console.ForegroundColor = foregroundColor;')
        [void]$framework.AppendLine('            Console.BackgroundColor = backgroundColor;')
        [void]$framework.AppendLine('            Console.Write(value);')
        [void]$framework.AppendLine('            Console.ForegroundColor = fgc;')
        [void]$framework.AppendLine('            Console.BackgroundColor = bgc;')
    }
    else {
        [void]$framework.AppendLine('            if ((!string.IsNullOrEmpty(value)) && (value != "\n"))')
        [void]$framework.AppendLine('                MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void Write(string value)')
[void]$framework.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            Console.Write(value);')
    }
    else {
        [void]$framework.AppendLine('            if ((!string.IsNullOrEmpty(value)) && (value != "\n"))')
        [void]$framework.AppendLine('                MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        // called by Write-Debug')
[void]$framework.AppendLine('        public override void WriteDebugLine(string message)')
[void]$framework.AppendLine('        {')

if (-not $NoError) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            WriteLineInternal(DebugForegroundColor, DebugBackgroundColor, string.Format("DEBUG: {0}", message));')
    }
    else {
        [void]$framework.AppendLine('            MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Information);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        // called by Write-Error')
[void]$framework.AppendLine('        public override void WriteErrorLine(string value)')
[void]$framework.AppendLine('        {')

if (-not $NoError) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            if (ConsoleInfo.IsErrorRedirected())')
        [void]$framework.AppendLine('                Console.Error.WriteLine(string.Format("ERROR: {0}", value));')
        [void]$framework.AppendLine('            else')
        [void]$framework.AppendLine('                WriteLineInternal(ErrorForegroundColor, ErrorBackgroundColor, string.Format("ERROR: {0}", value));')
    }
    else {
        [void]$framework.AppendLine('            MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void WriteLine()')
[void]$framework.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            Console.WriteLine();')
    }
    else {
        [void]$framework.AppendLine('            MessageBox.Show("", System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void WriteLine(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)')
[void]$framework.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;')
        [void]$framework.AppendLine('            Console.ForegroundColor = foregroundColor;')
        [void]$framework.AppendLine('            Console.BackgroundColor = backgroundColor;')
        [void]$framework.AppendLine('            Console.WriteLine(value);')
        [void]$framework.AppendLine('            Console.ForegroundColor = fgc;')
        [void]$framework.AppendLine('            Console.BackgroundColor = bgc;')
    } else {
        [void]$framework.AppendLine('            if ((!string.IsNullOrEmpty(value)) && (value != "\n"))')
        [void]$framework.AppendLine('                MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$framework.AppendLine('        }')


if ((-not $NoError) -and (-not $NoConsole)) {
    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        private void WriteLineInternal(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)')
    [void]$framework.AppendLine('        {')
    [void]$framework.AppendLine('            ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;')
    [void]$framework.AppendLine('            Console.ForegroundColor = foregroundColor;')
    [void]$framework.AppendLine('            Console.BackgroundColor = backgroundColor;')
    [void]$framework.AppendLine('            Console.WriteLine(value);')
    [void]$framework.AppendLine('            Console.ForegroundColor = fgc;')
    [void]$framework.AppendLine('            Console.BackgroundColor = bgc;')
    [void]$framework.AppendLine('        }')
}


[void]$framework.AppendLine()
[void]$framework.AppendLine('        // called by Write-Output')
[void]$framework.AppendLine('        public override void WriteLine(string value)')
[void]$framework.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            Console.WriteLine(value);')
    } else {
        [void]$framework.AppendLine('            if ((!string.IsNullOrEmpty(value)) && (value != "\n"))')
        [void]$framework.AppendLine('                MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);')
    }
}

[void]$framework.AppendLine('        }')


if ($NoConsole) {
    [void]$framework.AppendLine()
    [void]$framework.AppendLine('        public ProgressForm pf = null;')
}


[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void WriteProgress(long sourceId, ProgressRecord record)')
[void]$framework.AppendLine('        {')

if ($NoConsole) {
    [void]$framework.AppendLine('            if (pf == null)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                pf = new ProgressForm(ProgressForegroundColor);')
    [void]$framework.AppendLine('                pf.Show();')
    [void]$framework.AppendLine('            }')
    [void]$framework.AppendLine('            pf.Update(record);')
    [void]$framework.AppendLine('            if (record.RecordType == ProgressRecordType.Completed)')
    [void]$framework.AppendLine('            {')
    [void]$framework.AppendLine('                pf = null;')
    [void]$framework.AppendLine('            }')
}

[void]$framework.AppendLine('        }')



[void]$framework.AppendLine()
[void]$framework.AppendLine('        // called by Write-Verbose')
[void]$framework.AppendLine('        public override void WriteVerboseLine(string message)')
[void]$framework.AppendLine('        {')

if (-not $NoOutput) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            WriteLine(VerboseForegroundColor, VerboseBackgroundColor, string.Format("VERBOSE: {0}", message));')
    }
    else {
        [void]$framework.AppendLine('            MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Information);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('        // called by Write-Warning')
[void]$framework.AppendLine('        public override void WriteWarningLine(string message)')
[void]$framework.AppendLine('        {')

if (-not $NoError) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('            WriteLineInternal(WarningForegroundColor, WarningBackgroundColor, string.Format("WARNING: {0}", message));')
    }
    else {
        [void]$framework.AppendLine('            MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Warning);')
    }
}

[void]$framework.AppendLine('        }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('    }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('    internal class PS2EXEHost : PSHost')
[void]$framework.AppendLine('    {')
[void]$framework.AppendLine('        private PS2EXEApp parent;')
[void]$framework.AppendLine('        private PS2EXEHostUI ui = null;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        private CultureInfo originalCultureInfo = System.Threading.Thread.CurrentThread.CurrentCulture;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        private CultureInfo originalUICultureInfo = System.Threading.Thread.CurrentThread.CurrentUICulture;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        private Guid myId = Guid.NewGuid();')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public PS2EXEHost(PS2EXEApp app, PS2EXEHostUI ui)')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            this.parent = app;')
[void]$framework.AppendLine('            this.ui = ui;')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public class ConsoleColorProxy')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            private PS2EXEHostUI _ui;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColorProxy(PS2EXEHostUI ui)')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                if (ui == null) throw new ArgumentNullException("ui");')
[void]$framework.AppendLine('                _ui = ui;')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor ErrorForegroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.ErrorForegroundColor; }')
[void]$framework.AppendLine('                set { _ui.ErrorForegroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor ErrorBackgroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.ErrorBackgroundColor; }')
[void]$framework.AppendLine('                set { _ui.ErrorBackgroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor WarningForegroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.WarningForegroundColor; }')
[void]$framework.AppendLine('                set { _ui.WarningForegroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor WarningBackgroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.WarningBackgroundColor; }')
[void]$framework.AppendLine('                set { _ui.WarningBackgroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor DebugForegroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.DebugForegroundColor; }')
[void]$framework.AppendLine('                set { _ui.DebugForegroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor DebugBackgroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.DebugBackgroundColor; }')
[void]$framework.AppendLine('                set { _ui.DebugBackgroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor VerboseForegroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.VerboseForegroundColor; }')
[void]$framework.AppendLine('                set { _ui.VerboseForegroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor VerboseBackgroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.VerboseBackgroundColor; }')
[void]$framework.AppendLine('                set { _ui.VerboseBackgroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor ProgressForegroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.ProgressForegroundColor; }')
[void]$framework.AppendLine('                set { _ui.ProgressForegroundColor = value; }')
[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            public ConsoleColor ProgressBackgroundColor')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                get { return _ui.ProgressBackgroundColor; }')
[void]$framework.AppendLine('                set { _ui.ProgressBackgroundColor = value; }')
[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override PSObject PrivateData')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                if (ui == null) return null;')
[void]$framework.AppendLine('                return _consoleColorProxy ?? (_consoleColorProxy = PSObject.AsPSObject(new ConsoleColorProxy(ui)));')
[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        private PSObject _consoleColorProxy;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override System.Globalization.CultureInfo CurrentCulture')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get { return this.originalCultureInfo; }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override System.Globalization.CultureInfo CurrentUICulture')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get { return this.originalUICultureInfo; }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override Guid InstanceId')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get { return this.myId; }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override string Name')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get { return "PS2EXE_Host"; }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override PSHostUserInterface UI')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get { return ui; }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override Version Version')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get { return new Version(0, 6, 1, 1); }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void EnterNestedPrompt()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void ExitNestedPrompt()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void NotifyBeginApplication()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            return;')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void NotifyEndApplication()')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            return;')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public override void SetShouldExit(int exitCode)')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            this.parent.ShouldExit = true;')
[void]$framework.AppendLine('            this.parent.ExitCode = exitCode;')
[void]$framework.AppendLine('        }')
[void]$framework.AppendLine('    }')

#endregion

#region PS2EXE Application

[void]$framework.AppendLine()
[void]$framework.AppendLine('    internal interface PS2EXEApp')
[void]$framework.AppendLine('    {')
[void]$framework.AppendLine('        bool ShouldExit { get; set; }')
[void]$framework.AppendLine('        int ExitCode { get; set; }')
[void]$framework.AppendLine('    }')


[void]$framework.AppendLine()
[void]$framework.AppendLine('    internal class PS2EXE : PS2EXEApp')
[void]$framework.AppendLine('    {')
[void]$framework.AppendLine('        private bool shouldExit;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        private int exitCode;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public bool ShouldExit')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get { return this.shouldExit; }')
[void]$framework.AppendLine('            set { this.shouldExit = value; }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        public int ExitCode')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            get { return this.exitCode; }')
[void]$framework.AppendLine('            set { this.exitCode = value; }')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()

if ($Apartment -eq 'STA') { [void]$framework.AppendLine('        [STAThread]') }
if ($Apartment -eq 'MTA') { [void]$framework.AppendLine('        [MTAThread]') }

[void]$framework.AppendLine('        private static int Main(string[] args)')
[void]$framework.AppendLine('        {')

if (-not [string]::IsNullOrEmpty($culture.ToString())) {
    [void]$framework.AppendFormat('            {0}', $culture.ToString()).AppendLine()
}

if ((-not $NoVisualStyles) -and $NoConsole) {
    [void]$framework.AppendLine()
    [void]$framework.AppendLine('            Application.EnableVisualStyles();')
}

[void]$framework.AppendLine()
[void]$framework.AppendLine('            PS2EXE me = new PS2EXE();')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            bool paramWait = false;')
[void]$framework.AppendLine('            string extractFN = string.Empty;')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            PS2EXEHostUI ui = new PS2EXEHostUI();')
[void]$framework.AppendLine('            PS2EXEHost host = new PS2EXEHost(me, ui);')
[void]$framework.AppendLine('            System.Threading.ManualResetEvent mre = new System.Threading.ManualResetEvent(false);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            AppDomain.CurrentDomain.UnhandledException += new UnhandledExceptionEventHandler(CurrentDomain_UnhandledException);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            try')
[void]$framework.AppendLine('            {')
[void]$framework.AppendLine('                using (Runspace myRunSpace = RunspaceFactory.CreateRunspace(host))')
[void]$framework.AppendLine('                {')

if ($Apartment -eq 'STA') { [void]$framework.AppendLine('                    myRunSpace.ApartmentState = System.Threading.ApartmentState.STA;') }
if ($Apartment -eq 'MTA') { [void]$framework.AppendLine('                    myRunSpace.ApartmentState = System.Threading.ApartmentState.MTA;') }

[void]$framework.AppendLine('                    myRunSpace.Open();')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                    using (System.Management.Automation.PowerShell powershell = System.Management.Automation.PowerShell.Create())')
[void]$framework.AppendLine('                    {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                        Console.CancelKeyPress += new ConsoleCancelEventHandler(delegate (object sender, ConsoleCancelEventArgs e)')
    [void]$framework.AppendLine('                        {')
    [void]$framework.AppendLine('                            try')
    [void]$framework.AppendLine('                            {')
    [void]$framework.AppendLine('                                powershell.BeginStop(new AsyncCallback(delegate (IAsyncResult r)')
    [void]$framework.AppendLine('                                {')
    [void]$framework.AppendLine('                                    mre.Set();')
    [void]$framework.AppendLine('                                    e.Cancel = true;')
    [void]$framework.AppendLine('                                }), null);')
    [void]$framework.AppendLine('                            }')
    [void]$framework.AppendLine('                            catch')
    [void]$framework.AppendLine('                            {')
    [void]$framework.AppendLine('                            };')
    [void]$framework.AppendLine('                        });')
}

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        powershell.Runspace = myRunSpace;')
[void]$framework.AppendLine('                        powershell.Streams.Error.DataAdded += new EventHandler<DataAddedEventArgs>(delegate (object sender, DataAddedEventArgs e)')
[void]$framework.AppendLine('                        {')
[void]$framework.AppendLine('                            ui.WriteErrorLine(((PSDataCollection<ErrorRecord>)sender)[e.Index].ToString());')
[void]$framework.AppendLine('                        });')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        PSDataCollection<string> colInput = new PSDataCollection<string>();')

if ($Runtime -ne '2.0') {
    [void]$framework.AppendLine('                        if (ConsoleInfo.IsInputRedirected())')
    [void]$framework.AppendLine('                        { // read standard input')
    [void]$framework.AppendLine('                            string sItem = "";')
    [void]$framework.AppendLine('                            while ((sItem = Console.ReadLine()) != null)')
    [void]$framework.AppendLine('                            { // add to powershell pipeline')
    [void]$framework.AppendLine('                                colInput.Add(sItem);')
    [void]$framework.AppendLine('                            }')
    [void]$framework.AppendLine('                        }')
}

[void]$framework.AppendLine('                        colInput.Complete();')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        PSDataCollection<PSObject> colOutput = new PSDataCollection<PSObject>();')
[void]$framework.AppendLine('                        colOutput.DataAdded += new EventHandler<DataAddedEventArgs>(delegate (object sender, DataAddedEventArgs e)')
[void]$framework.AppendLine('                        {')
[void]$framework.AppendLine('                            ui.WriteLine(colOutput[e.Index].ToString());')
[void]$framework.AppendLine('                        });')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        int separator = 0;')
[void]$framework.AppendLine('                        int idx = 0;')
[void]$framework.AppendLine('                        foreach (string s in args)')
[void]$framework.AppendLine('                        {')
[void]$framework.AppendLine('                            if (string.Compare(s, "-Wait", true) == 0)')
[void]$framework.AppendLine('                                paramWait = true;')
[void]$framework.AppendLine('                            else if (s.StartsWith("-Extract", StringComparison.InvariantCultureIgnoreCase))')
[void]$framework.AppendLine('                            {')
[void]$framework.AppendLine('                                string[] s1 = s.Split(new string[] { ":" }, 2, StringSplitOptions.RemoveEmptyEntries);')
[void]$framework.AppendLine('                                if (s1.Length != 2)')
[void]$framework.AppendLine('                                {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                                    Console.WriteLine("If you specify the -Extract option you need to add a file for extraction in this way\r\n   -Extract:\"<filename>\"");')
}
else {
    [void]$framework.AppendLine('                                    MessageBox.Show("If you specify the -Extract option you need to add a file for extraction in this way\r\n   -Extract:\"<filename>\"", System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);')
}

[void]$framework.AppendLine('                                    return 1;')
[void]$framework.AppendLine('                                }')
[void]$framework.AppendLine('                                extractFN = s1[1].Trim(new char[] { ''\"'' });')
[void]$framework.AppendLine('                            }')
[void]$framework.AppendLine('                            else if (string.Compare(s, "-End", true) == 0)')
[void]$framework.AppendLine('                            {')
[void]$framework.AppendLine('                                separator = idx + 1;')
[void]$framework.AppendLine('                                break;')
[void]$framework.AppendLine('                            }')
[void]$framework.AppendLine('                            else if (string.Compare(s, "-Debug", true) == 0)')
[void]$framework.AppendLine('                            {')
[void]$framework.AppendLine('                                System.Diagnostics.Debugger.Launch();')
[void]$framework.AppendLine('                                break;')
[void]$framework.AppendLine('                            }')
[void]$framework.AppendLine('                            idx++;')
[void]$framework.AppendLine('                        }')

[void]$framework.AppendLine()
[void]$framework.AppendFormat('                        string script = System.Text.Encoding.UTF8.GetString(System.Convert.FromBase64String(@"{0}"));', $script).AppendLine()

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        if (!string.IsNullOrEmpty(extractFN))')
[void]$framework.AppendLine('                        {')
[void]$framework.AppendLine('                            System.IO.File.WriteAllText(extractFN, script);')
[void]$framework.AppendLine('                            return 0;')
[void]$framework.AppendLine('                        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        powershell.AddScript(script);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        // parse parameters')
[void]$framework.AppendLine('                        string argbuffer = null;')
[void]$framework.AppendLine('                        // regex for named parameters')
[void]$framework.AppendLine('                        System.Text.RegularExpressions.Regex regex = new System.Text.RegularExpressions.Regex(@"^-([^: ]+)[ :]?([^:]*)$");')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        for (int i = separator; i < args.Length; i++)')
[void]$framework.AppendLine('                        {')
[void]$framework.AppendLine('                            System.Text.RegularExpressions.Match match = regex.Match(args[i]);')
[void]$framework.AppendLine('                            if (match.Success && match.Groups.Count == 3)')
[void]$framework.AppendLine('                            { // parameter in powershell style, means named parameter found')
[void]$framework.AppendLine('                                if (argbuffer != null) // already a named parameter in buffer, then flush it')
[void]$framework.AppendLine('                                    powershell.AddParameter(argbuffer);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                                if (match.Groups[2].Value.Trim() == "")')
[void]$framework.AppendLine('                                { // store named parameter in buffer')
[void]$framework.AppendLine('                                    argbuffer = match.Groups[1].Value;')
[void]$framework.AppendLine('                                }')
[void]$framework.AppendLine('                                else')
[void]$framework.AppendLine('                                    // caution: when called in powershell $true gets converted, when called in cmd.exe not')
[void]$framework.AppendFormat('                                    if ((match.Groups[2].Value == "{0}") || (match.Groups[2].Value.ToUpper() == "\x24" + "TRUE"))', $true).AppendLine()
[void]$framework.AppendLine('                                { // switch found')
[void]$framework.AppendLine('                                    powershell.AddParameter(match.Groups[1].Value, true);')
[void]$framework.AppendLine('                                    argbuffer = null;')
[void]$framework.AppendLine('                                }')
[void]$framework.AppendLine('                                else')
[void]$framework.AppendLine('                                    // caution: when called in powershell $false gets converted, when called in cmd.exe not')
[void]$framework.AppendFormat('                                    if ((match.Groups[2].Value == "{0}") || (match.Groups[2].Value.ToUpper() == "\x24" + "FALSE"))', $false).AppendLine()
[void]$framework.AppendLine('                                { // switch found')
[void]$framework.AppendLine('                                    powershell.AddParameter(match.Groups[1].Value, false);')
[void]$framework.AppendLine('                                    argbuffer = null;')
[void]$framework.AppendLine('                                }')
[void]$framework.AppendLine('                                else')
[void]$framework.AppendLine('                                { // named parameter with value found')
[void]$framework.AppendLine('                                    powershell.AddParameter(match.Groups[1].Value, match.Groups[2].Value);')
[void]$framework.AppendLine('                                    argbuffer = null;')
[void]$framework.AppendLine('                                }')
[void]$framework.AppendLine('                            }')
[void]$framework.AppendLine('                            else')
[void]$framework.AppendLine('                            { // unnamed parameter found')
[void]$framework.AppendLine('                                if (argbuffer != null)')
[void]$framework.AppendLine('                                { // already a named parameter in buffer, so this is the value')
[void]$framework.AppendLine('                                    powershell.AddParameter(argbuffer, args[i]);')
[void]$framework.AppendLine('                                    argbuffer = null;')
[void]$framework.AppendLine('                                }')
[void]$framework.AppendLine('                                else')
[void]$framework.AppendLine('                                { // position parameter found')
[void]$framework.AppendLine('                                    powershell.AddArgument(args[i]);')
[void]$framework.AppendLine('                                }')
[void]$framework.AppendLine('                            }')
[void]$framework.AppendLine('                        }')
[void]$framework.AppendLine()
[void]$framework.AppendLine('                        if (argbuffer != null) powershell.AddParameter(argbuffer); // flush parameter buffer...')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        // convert output to strings')
[void]$framework.AppendLine('                        powershell.AddCommand("out-string");')
[void]$framework.AppendLine('                        // with a single string per line')
[void]$framework.AppendLine('                        powershell.AddParameter("stream");')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        powershell.BeginInvoke<string, PSObject>(colInput, colOutput, null, new AsyncCallback(delegate (IAsyncResult ar)')
[void]$framework.AppendLine('                        {')
[void]$framework.AppendLine('                            if (ar.IsCompleted)')
[void]$framework.AppendLine('                                mre.Set();')
[void]$framework.AppendLine('                        }), null);')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        while (!me.ShouldExit && !mre.WaitOne(100))')
[void]$framework.AppendLine('                        { };')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        powershell.Stop();')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                        if (powershell.InvocationStateInfo.State == PSInvocationState.Failed)')
[void]$framework.AppendLine('                            ui.WriteErrorLine(powershell.InvocationStateInfo.Reason.Message);')
[void]$framework.AppendLine('                    }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('                    myRunSpace.Close();')
[void]$framework.AppendLine('                }')
[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            catch (Exception ex)')
[void]$framework.AppendLine('            {')

if (-not $NoError) {
    if (-not $NoConsole) {
        [void]$framework.AppendLine('                Console.Write("An exception occured: ");')
        [void]$framework.AppendLine('                Console.WriteLine(ex.Message);')
    }
    else {
        [void]$framework.AppendLine('                MessageBox.Show("An exception occured: " + ex.Message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);')
    }
}

[void]$framework.AppendLine('            }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('            if (paramWait)')
[void]$framework.AppendLine('            {')

if (-not $NoConsole) {
    [void]$framework.AppendLine('                Console.WriteLine("Hit any key to exit...");')
    [void]$framework.AppendLine('                Console.ReadKey();')
}
else {
    [void]$framework.AppendLine('                MessageBox.Show("Click OK to exit...", System.AppDomain.CurrentDomain.FriendlyName);')
}

[void]$framework.AppendLine('            }')
[void]$framework.AppendLine('            return me.ExitCode;')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('        static void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)')
[void]$framework.AppendLine('        {')
[void]$framework.AppendLine('            throw new Exception("Unhandled exception in PS2EXE");')
[void]$framework.AppendLine('        }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('    }')

[void]$framework.AppendLine()
[void]$framework.AppendLine('}')

#endregion

#endregion

#endregion


Write-Host 'Compiling file...'
$compilerResults = $codeProvider.CompileAssemblyFromSource($compilerParameters, $framework.ToString())


if ($compilerResults.Errors.Count -gt 0) {
    if (Test-Path -Path $OutputFile) { Remove-Item -Path $OutputFile -Force }

    Write-Error ('Could not create the PowerShell executable because of compilation errors. ' + `
        'Use -Verbose parameter to see details.') -ErrorAction Continue

    $compilerResults.Errors | ForEach-Object { Write-Verbose $_ }

    # exit
    return
}
else {
    if (Test-Path -Path $OutputFile) {
        Write-Host ('Output file "{0}" written' -f $OutputFile)

        if ($PSBoundParameters.ContainsKey('Debug')) {
            $compilerResults.TempFiles | Where-Object { $_ -like '*.cs' } | Select-Object -First 1 | ForEach-Object {
                $source = (
                    [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($OutputFile),
                        [System.IO.Path]::GetFileNameWithoutExtension($OutputFile) + '.cs'
                    )
                )

                Write-Debug ('Source file copied: {0}' -f $source)
                Copy-Item -Path $_ -Destination $source -Force
            }

            $compilerResults.TempFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        if ((-not $NoConfigFile) -or $LongPaths) {
            Write-Host 'Creating config file for executable...'

            $config = New-Object -TypeName System.Text.StringBuilder

            [void]$config.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
            [void]$config.AppendLine('<configuration>')
            [void]$config.AppendLine('  <startup>')

            if ($Runtime -eq '2.0') { [void]$config.AppendLine('    <supportedRuntime version="v2.0.50727"/>') }
            if ($Runtime -eq '4.0') { [void]$config.AppendLine('    <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.0"/>') }

            [void]$config.AppendLine('  </startup>')

            if (($Runtime -eq '4.0') -and $LongPaths) {
                [void]$config.AppendLine('  <runtime>')
                [void]$config.AppendLine('    <AppContextSwitchOverrides value="Switch.System.IO.UseLegacyPathHandling=false;Switch.System.IO.BlockLongPaths=false"/>')
                [void]$config.AppendLine('  </runtime>')
            }

            [void]$config.AppendLine('</configuration>')

            $config.ToString() -replace '\s*$' | Set-Content ($OutputFile + '.config') -Encoding UTF8
        }
    }
    else {
        Write-Error ('Output file "{0}" not written' -f $OutputFile)
    }
}

if ($RequireAdmin -or $SupportedOS -or $LongPaths) {
    if (Test-Path -Path ($OutputFile + '.win32manifest')) {
        Remove-Item -Path ($OutputFile + '.win32manifest') -Force
    }
}
