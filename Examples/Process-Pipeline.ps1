# Example script to process pipeline

# Type of pipeline object gets lost for compiled scripts, pipeline objects are always strings

[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline = $true)]
    [AllowEmptyString()]
    [System.Object]$Pipeline
)

begin {
    $counter = 0

    Write-Output 'Reading pipeline as array of strings'
}

process {
    if ($null -eq $Pipeline) {
        Write-Output 'No element found in the pipeline'
    }
    else {
        $counter++

        Write-Output ('{0}: {1}' -f $counter, $Pipeline)
    }
}
