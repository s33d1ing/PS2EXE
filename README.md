# PS2EXE

Overworking of the great script of Ingo Karstein with GUI support.  
The GUI output and input is activated with one switch, real windows executables are generated.  
With PowerShell 5.x support and graphical front end.  

Module version.

Author: Markus Scholtes, Garrett Dees  
Version: 2.0.0  
Date: 2020-04-10  

You find the script based version here: [PS2EXE-GUI: "Convert" PowerShell Scripts to EXE Files with GUI](https://gallery.technet.microsoft.com/PS2EXE-GUI-Convert-e7cb69d5).


## Usage

### Compiles "source.ps1" into the executable "target.exe":

``` PowerShell
Invoke-PS2EXE .\source.ps1 .\target.exe
```

or

``` PowerShell
PS2EXE .\source.ps1 .\target.exe
```

If ".\target.exe" is omitted, output is written to ".\source.exe".


## Parameter

```
ps2exe.ps1 [-InputFile] <string> [[-OutputFile] <string>] [[-IconFile] <string>]

    [-FileDescription <string>] [-FileVersion <string>] [-ProductName <string>] [-ProductVersion <string>]
    [-LegalCopyright <string>] [-LegalTrademark <string>] [-CompanyName <string>] [-Comments <string>]

    [-Runtime {2.0 | 4.0}] [-Platform {AnyCPU | x86 | x64}] [-Apartment {STA | MTA}] [-LCID <ID>]

    [-NoConfigFile:<bool>] [-NoConsole] [-NoOutput] [-NoError]
    [-CredentialGui] [-RequireAdmin] [-SupportOS] [-Virtualize] [-LongPaths]


       InputFile = PowerShell script that you want to convert to executable')
      OutputFile = Destination executable file name, defaults to InputFile with extension ".exe"')
        IconFile = Icon file name for the compiled executable')

 FileDescription = AssemblyTitle (File Description in details tab of File Explorer''s properties dialog)
     FileVersion = AssemblyFileVersion (File Version in details tab of File Explorer''s properties dialog)
     ProductName = AssemblyProduct (Product Name in details tab of File Explorer''s properties dialog)
  ProductVersion = AssemblyInformationalVersion (Product Version in details tab of File Explorer''s properties dialog)
  LegalCopyright = AssemblyCopyright (Copyright in details tab of File Explorer''s properties dialog)
  LegalTrademark = AssemblyTrademark (Legal Trademark in details tab of File Explorer''s properties dialog)
     CompanyName = AssemblyCompany (Not displayed in File Explorer, but embedded in executable)
        Comments = AssemblyDescription (Not displayed in File Explorer, but embedded in executable)

         Runtime = Choose between generating a config file that contains the "support .NET Framework versions" settings
                   for .NET Framework 2.0/3.x for PowerShell 2.0 or for .NET Framework 4.x for PowerShell 3.0 or higher
        Platform = Choose between compiling for AnyCPU, or 32-bit or 64-bit runtime only
       Apartment = Choose between a single-threaded apartment or a multithreaded apartment
            LCID = location ID for the compiled executable. Current user culture if not specified

    NoConfigFile = Do not write a config file (<OutputFile>.exe.config)
       NoConsole = The resulting executable will be a Windows Forms application without a console window
        NoOutput = The resulting executable will generate no standard output (includes verbose and information streams)
         NoError = The resulting executable will generate no error output (includes warning and debug streams)
   CredentialGui = Use GUI for prompting credentials in console mode instead of console input
    RequireAdmin = if UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required)
     SupportedOS = Use functions of newest Windows versions (run [System.Environment]::OSVersion to see version)
      Virtualize = application virtualization is activated (forcing x86 runtime)
       LongPaths = Enable long paths (>260 characters) if enabled on OS (only works with Windows 10)
```

A generated executables has the following reserved parameters:

```
-Debug              Forces the executable to be debugged by calling "System.Diagnostics.Debugger.Break()"

-Extract:<Path>     Extracts the PowerShell script inside the executable and saves it as the specified Path
                    The script will not be executed.

-Wait               Pauses at the end of the script execution and waits for a key to be pressed

-End                All following options will be passed to the script inside the executable
                    All preceding options are used by the executable itself
```


## Remarks

### GUI mode output formatting:

Per default in powerShell outputs of commandlets are formatted line per line (as an array of strings). When your command generates 10 lines of output and you use GUI output, 10 message boxes will appear each awaiting for an OK. To prevent this pipe your commandto the comandlet Out-String. This will convert the output to one string array with 10 lines, all output will be shown in one message box (for example: dir C:\ | Out-String).

### Config files:

PS2EXE can create config files with the name of the generated executable + ".config". In most cases those config files are not necessary, they are a manifest that tells which .Net Framework version should be used. As you will usually use the actual .Net Framework, try running your excutable without the config file.

### Password security:

Never store passwords in your compiled script! One can simply decompile the script with the parameter -extract. For example

``` PowerShell
Output.exe -Extract:C:\Output.ps1
```
will decompile the script stored in Output.exe.

### Script variables:

Since PS2EXE converts a script to an executable, script related variables are not available anymore. Especially the variable $PSScriptRoot is empty.

The variable $MyInvocation is set to other values than in a script.

You can retrieve the script/executable path independant of compiled/not compiled with the following code (thanks to JacquesFS):

``` PowerShell
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    $ScriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
}
else {
    $ScriptPath = Split-Path -Path ([Environment]::GetCommandLineArgs()[0]) -Parent
    if (-not $ScriptPath) { $ScriptPath = '.' }
}
```

### Window in background in -noConsole mode:

When an external window is opened in a script with -noConsole mode (i.e. for Get-Credential or for a command that needs a cmd.exe shell) the next window is opened in the background.

The reason for this is that on closing the external window windows tries to activate the parent window. Since the compiled script has no window, the parent window of the compiled script is activated instead, normally the window of Explorer or PowerShell.

To work around this, $Host.UI.RawUI.FlushInputBuffer() opens an invisible window that can be activated. The following call of $Host.UI.RawUI.FlushInputBuffer() closes this window (and so on).

The following example will not open a window in the background anymore as a single call of "ipconfig | Out-String" will do:

``` PowerShell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```


## Changes:
### 2.0.0 / 2020-04-10
  - **G. Dees:** Write prompt to console after viewing help message
  - **G. Dees:** Updated parameter names and combined several using sets
  - **G. Dees:** Restructured module and created new Manifest and Script file

### 1.1.1 / 2020-04-03
- **G. Dees:** Moved populating PSScriptRoot and PSCommandPath out of Invoke-PS2EXE

### 1.1.0 / 2020-04-02
- **G. Dees:** Refactor of PS2EXE (still backwards compatible)

### 1.0.3 / 2020-02-15
- Converted files from UTF-16 to UTF-8 to allow git diff
- Ignore control keys in secure string request in console mode

### 1.0.2 / 2020-01-08
- Added examples

### 1.0.1 / 2019-12-16
- Fixed "unlimited window width for GUI windows" issue in ps2exe.ps1 and Win-PS2EXE

### 1.0.0 / 2019-11-08
- First stable module version

### 0.0.0 / 2019-09-15
- Experimental
