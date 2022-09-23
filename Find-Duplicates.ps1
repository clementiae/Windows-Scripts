param (
    [Parameter(Mandatory = $true)]
    $InputDirectory
)

Write-Host "Calculating files' hashes..." -ForegroundColor Cyan
[string]$HASH_FILE = Join-Path -Path $env:TEMP -ChildPath "FilesHash.csv" 
Get-ChildItem -Path $InputDirectory -Recurse | Get-FileHash -Algorithm MD5 | Export-Csv -Path $HASH_FILE -NoTypeInformation

$P = Import-Csv -Path $HASH_FILE

Write-Host "Finding duplicates..." -ForegroundColor Cyan
$duplicateCount = 0
for ($i = 0; $i -le $P.Length; $i++) {
    for ($j = $i + 1; $j -le $P.Length; $j++) {
        if ($P[$i].Hash -ceq $P[$j].Hash ) {
            $duplicateCount = $duplicateCount + 1
            Write-Host "Duplicate items number $i and $j at:" -ForegroundColor DarkYellow
            Write-Host "$($P[$i].Path)" -ForegroundColor Green
            Write-Host "$($P[$j].Path)" -ForegroundColor Red
            $promptAnswer = Read-Host -Prompt "Delete duplicate? (Y/n)"
            if ($promptAnswer -eq "Y") {
                Remove-Item -Path $P[$j].Path
                Write-Host "Deleted $($P[$j].Path)" -ForegroundColor DarkGreen
            }
            if ($promptAnswer -eq "N") {
                continue
            }
        }
    }
}

if ($duplicateCount -eq 0) {
    Write-Host "No duplicates found!" -ForegroundColor Magenta
}
else {
    Write-Host "Removed $duplicateCount duplicates." -ForegroundColor Magenta
}

Write-Host "Cleaning up..." -ForegroundColor Cyan
Remove-Item -Path $HASH_FILE
Write-Host "Done." -ForegroundColor Green