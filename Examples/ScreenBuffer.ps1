# Example script for screen operations

function Get-CharFromConsolePosition ([int]$X, [int]$Y) {
    # Function to get the character of a position in the console buffer
      $Rectangle = New-Object -TypeName System.Management.Automation.Host.Rectangle -ArgumentList $X, $Y, $X, $Y
      $Host.UI.RawUI.GetBufferContents($Rectangle)[0, 0]
}


# Fill block with a character

# Complete - The character occupies one BufferCell structure.
# Leading - The character occupies two BufferCell structures, with this cell being the leading cell (UNICODE)
# Trailing - The character occupies two BufferCell structures, with this cell being the trailing cell  (UNICODE)

$BufferCell = New-Object System.Management.Automation.Host.BufferCell -ArgumentList 'O', 'White', 'Red', 'Complete'
$Source = New-Object System.Management.Automation.Host.Rectangle -ArgumentList 10, 10, 29, 29

$Host.UI.RawUI.SetBufferContents($Source, $BufferCell)


# Read block into buffer
$ScreenBuffer = New-Object -TypeName 'System.Management.Automation.Host.BufferCell[,]' -ArgumentList ($Source.Bottom - $Source.Top + 1), ($Source.Right - $Source.Left + 1)
$ScreenBuffer = $Host.UI.RawUI.GetBufferContents($Source)


# Modify block in buffer
$MaxDimension = [System.Math]::Min(($Source.Bottom - $Source.Top + 1), ($Source.Right - $Source.Left + 1))

for ($counter = 0; $counter -lt $MaxDimension; $counter++) {
    $ScreenBuffer[$counter, $counter] = New-Object -TypeName System.Management.Automation.Host.BufferCell -ArgumentList 'X', 'White', 'Red', 'Complete'
    $ScreenBuffer[($MaxDimension - $counter - 1), $counter] = New-Object -TypeName System.Management.Automation.Host.BufferCell -ArgumentList 'X', 'White', 'Red', 'Complete'
}


# Write back buffer to screen
$Host.UI.RawUI.SetBufferContents((New-Object -TypeName System.Management.Automation.Host.Coordinates -ArgumentList $Source.Left, $Source.Top), $ScreenBuffer)


# Move block

# Define fill character for source range
$BufferCell.Character = '-'
$BufferCell.ForegroundColor = $Host.UI.RawUI.ForegroundColor
$BufferCell.BackgroundColor = $Host.UI.RawUI.BackgroundColor

# Define clipping area (a ten character wide border)
$Clip = New-Object -TypeName System.Management.Automation.Host.Rectangle -ArgumentList 10, 10, ($Host.UI.RawUI.WindowSize.Width - 10), ($Host.UI.RawUI.WindowSize.Height - 10)

# Repeat ten times
for ($i = 1; $i -le 10; $i++) {
    for ($X = $Source.Left + 1; $X -le ($Host.UI.RawUI.WindowSize.Width - $Source.Right + $Source.Left); $X++) {
        $Destination = New-Object -TypeName System.Management.Automation.Host.Coordinates -ArgumentList $X, 10
        $Host.UI.RawUI.ScrollBufferContents($Source, $Destination, $Clip, $BufferCell)
        $Source.Right++
        $Source.Left++
    }

    for ($Y = $Source.Top + 1; $Y -le ($Host.UI.RawUI.WindowSize.Height - $Source.Bottom + $Source.Top); $Y++) {
        $Destination = New-Object -TypeName System.Management.Automation.Host.Coordinates -ArgumentList $Source.Left, $Y
        $Host.UI.RawUI.ScrollBufferContents($Source, $Destination, $Clip, $BufferCell)
        $Source.Bottom++
        $Source.Top++
    }

    for ($X = $Source.Left - 1; $X -ge 10; $X--) {
        $Destination = New-Object -TypeName System.Management.Automation.Host.Coordinates -ArgumentList $X, $Source.Top
        $Host.UI.RawUI.ScrollBufferContents($Source, $Destination, $Clip, $BufferCell)
        $Source.Right--
        $Source.Left--
    }

    for ($Y = $Source.Top - 1; $Y -ge 10; $Y--) {
        $Destination = New-Object -TypeName System.Management.Automation.Host.Coordinates -ArgumentList $Source.Left, $Y
        $Host.UI.RawUI.ScrollBufferContents($Source, $Destination, $Clip, $BufferCell)
        $Source.Bottom--
        $Source.Top--
    }
}


# Get character from screen
Write-Host ('Character at position (10/10): {0}' -f (Get-CharFromConsolePosition -X 10 -Y 10))
