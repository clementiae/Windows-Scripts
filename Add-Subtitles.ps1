param (
    [Parameter(Mandatory = $true)]
    $InputDirectory,
    [Parameter(Mandatory = $true)]
    $SubtitleDirectory,
    [Parameter(Mandatory = $true)]
    $OutputDirectory
)

$EpisodeList = Get-ChildItem -Path $InputDirectory
$SubtitleList = Get-ChildItem -Path $SubtitleDirectory

Write-Host "$($EpisodeList.Length) episodes found..." -ForegroundColor DarkMagenta
Write-Host "$($SubtitleList.Length) subtitle files found..." -ForegroundColor DarkMagenta

$Counter = 0
for ($i = 0; $i -lt $EpisodeList.Length; $i++)
{
    # Add another way to detect episode names in the format: S{XX}E{XX} - {Episode Name}.mkv
    # Check videofile itself, if no episode name check subtitle name, or fetch from the Internet
    [string]$EpisodeName = [regex]::Split($SubtitleList[$i].Name, '(S\d{2}E\d{2})')[1] + " -" + [regex]::Split($SubtitleList[$i].Name, '(S\d{2}E\d{2})')[2].split(".srt")[0] + ".mkv"
    [string]$OutputPath = Join-Path -Path $OutputDirectory -ChildPath $EpisodeName

    Write-Host "Remuxing $($OutputPath)" -ForegroundColor Magenta
    
    ffmpeg -hide_banner -v quiet -stats -i $EpisodeList[$i].FullName -sub_charenc UTF-8 -f srt -i $SubtitleList[$i].FullName `
    -map 0:v:0 -map 0:a:0 -map 1:0 -c:v copy -c:a copy -c:s srt -metadata:s:s:0 language=eng -metadata:s:s:0 title="English" `
    -metadata:s:a:0 title="English 5.1" $OutputPath

    $Counter = $Counter + 1
}

Write-Host "Remuxed $($Counter) files." -ForegroundColor Green
Write-Host "Done." -ForegroundColor Green