param (
    [Parameter(Mandatory = $true)]
    $InputDirectory,
    [Parameter(Mandatory = $true)]
    $Prefix
)

Write-Host "Renaming..." -ForegroundColor Magenta
Get-ChildItem -Path $InputDirectory | Rename-Item -NewName { [string]$Prefix + $_.Name }
Write-Host "Done." -ForegroundColor Green