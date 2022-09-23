param(
    [Parameter(Position = 0)]
    [string]$InputFile,
    [Parameter(Position = 1)]
    [string]$Algorithm,
    [Parameter(Position = 2)]
    [string]$Hash
)

$InputFileHash = (Get-FileHash $InputFile -Algorithm $Algorithm).Hash.ToUpper()

if ($InputFileHash -eq $Hash.ToUpper()) {
    Write-Host "Checksum verified!" -ForegroundColor Green
} else {
    Write-Host "Checksum not verified!" -ForegroundColor Red
    Write-Host "Input file checksum: " -NoNewline -ForegroundColor DarkRed
    for ($i = 0; $i -lt $InputFileHash.Length; $i++) {
        if ($InputFileHash[$i] -ne $Hash.ToUpper()[$i]) {
            Write-Host $InputFileHash[$i] -ForegroundColor Red -NoNewline
        } else {
            Write-Host $InputFileHash[$i] -NoNewline
        }
    }
    Write-Host "`nUser input checksum: " -NoNewline -ForegroundColor DarkGreen
    for ($i = 0; $i -lt $InputFileHash.Length; $i++) {
        if ($InputFileHash[$i] -ne $Hash.ToUpper()[$i]) {
            Write-Host $Hash.ToUpper()[$i] -ForegroundColor Green -NoNewline
        } else {
            Write-Host $Hash.ToUpper()[$i] -NoNewline
        }
    }
}