# Demo program for Write-Progress

for ($i = 1; $i -le 10; $i++) {
    Write-Progress -Activity 'Outer loop' -Status ('Counting {0} out of 10' -f $i) -Id 1 -PercentComplete ($i * 10)
    Start-Sleep -Milliseconds 10

    for ($j = 1; $j -le 100; $j++) {
        Write-Progress -Activity 'Inner loop' -Status ('Counting {0} out of 100' -f $j) -Id 2 -PercentComplete $j -ParentId 1
        Start-Sleep -Milliseconds 10
    }

    Write-Progress -Activity 'Inner loop' -Status 'Complete' -Id 2 -Completed
}

Write-Progress -Activity 'Outer loop' -Status 'Complete' -Id 1 -Completed
Write-Output 'Completed'
