# Markus Scholtes, 2020
# Execute parameters and pipeline as powershell commands

# Arguments found, arguments are commands, pipeline elements are input
if ($args) {
    $command = $args -join ' '

    # Build string out of pipeline (if any)
    foreach ($item in $input) {
        if ($pipeline) { $pipeline = '{0}, "{1}"' -f $pipeline, $item }
        else { $pipeline = '"{0}"' -f $item }
    }

    if ($pipeline) { $command = '{0}|{1}' -f $pipeline, $command }
}

# No arguments passed, pipeline elements are commands
else {
    # Build string out of pipeline (if any)
    foreach ($item in $input) {
        if ($command) { $command = '{0}; {1}' -f $command, $item }
        else { $command = $item }
    }
}

# Execute the passed commands
if ($command) { Invoke-Expression -Command $command | Out-String }
else { Write-Output 'Pass PowerShell commands as parameters or in pipeline' }
