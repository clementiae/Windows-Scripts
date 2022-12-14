param (
    [Parameter(Mandatory = $true)]
    $InputFile,
    $FileSize=$null,
    $CRF=32,
    $ClipBitrate=$null,
    $Crop=$null,
    $Width=1280,
    $ScalingAlgorithm="lanczos",
    $EncodingProfile="Slow",
    $PixelFormat="yuv420p10le",
    [Parameter(Mandatory = $true)]
    $OutputFile
)

if ($EncodingProfile -eq "Fast") {
    $CPU_USED = 2
    $TileColumns = 1
    $Threads = 2
} elseif ($EncodingProfile -eq "Slow") {
    $CPU_USED = 0
    $TileColumns = 0
    $Threads = 1
}

if ($PixelFormat -eq "yuv420p") {
    $VP9_Profile = 0
} elseif ($PixelFormat -eq "yuv420p10le") {
    $VP9_Profile = 2
}

# Set output WebM path
$WebmPath = 'D:\Random\WebM'
[string]$OUTPUT_WEBM = Join-Path -Path $WebmPath -ChildPath $OutputFile

# Set ffmpeg log path
[string]$TWOPASS_FILE = Join-Path -Path $env:TEMP -ChildPath "$($OutputFile.Split('.webm')[0].Replace(' ', '_'))_ffmpeg2pass" 

# Calculate clip duration using ffprobe
$ClipDuration = ffprobe -v error -hide_banner -of default=noprint_wrappers=0 `
-print_format flat -select_streams v:0 -show_entries `
format=duration $InputFile | ForEach-Object { [double] $_.Split('=')[1].Split('"')[1] }

# Calculate WebM bitrate
if ($null -eq $FileSize)
{
    # Default size 3MB
    $FileSize = 3072
} else {
    $FileSize = $FileSize * 1024
}
if ($null -eq $ClipBitrate)
{
    $ClipBitrate = [math]::Round((($FileSize * 8) / $ClipDuration), 2)
}
$MaxRate = $ClipBitrate + ($ClipBitrate * 0.3)
$MinRate = $ClipBitrate / 2

# Detect Crop if no value provided
if ($null -eq $Crop)
{
    [string]$STDOUT_FILE = Join-Path -Path $env:TEMP -ChildPath "stdout.txt"
    $ArgumentList = "-i $InputFile -vframes 10 -vf cropdetect -f null NUL"
    Start-Process -FilePath ffmpeg -ArgumentList $ArgumentList -Wait -NoNewWindow `
    -RedirectStandardError $STDOUT_FILE
    $Crop = (((Get-Content -LiteralPath $STDOUT_FILE | Where-Object { $_ -Like '*crop=*' }).Split(" "))[13]).Split("=")[1]
}


Write-Host -NoNewline ("WebM duration: ");          Write-Host -ForegroundColor DarkYellow ("{0}s" -f $ClipDuration)
Write-Host -NoNewline ("WebM size: ");              Write-Host -ForegroundColor DarkYellow ("{0}k" -f $FileSize)
Write-Host -NoNewline ("WebM bitrate: ");           Write-Host -ForegroundColor DarkYellow ("{0}k" -f $ClipBitrate)
Write-Host -NoNewline ("Constant Rate Factor: ");   Write-Host -ForegroundColor DarkYellow ("{0}" -f $CRF)
Write-Host -NoNewline ("Video crop: ");             Write-Host -ForegroundColor DarkYellow ("{0}" -f $Crop)
Write-Host -NoNewline ("Scaling algorithm: ");      Write-Host -ForegroundColor DarkYellow ("{0}" -f $ScalingAlgorithm)
Write-Host -NoNewline ("Pixel format: ");           Write-Host -ForegroundColor DarkYellow ("{0}" -f $PixelFormat)
Write-Host -NoNewline ("Encoding profile: ");       Write-Host -ForegroundColor DarkYellow ("{0}" -f $EncodingProfile)


Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
Write-Host "Encoding to WebM..."
$isSubtitles = ffprobe -hide_banner -v error -show_streams -select_streams s $InputFile
$isAudio = ffprobe -hide_banner -v error -show_streams -select_streams a $InputFile
$PerformanceTime = Measure-Command -Expression {
    # Check if contains audio
    if ($null -ne $isAudio) {
            Write-Host "Audio detected." -ForegroundColor Magenta
    
            Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
            Write-Host "Performing first pass..."

            ffmpeg -hide_banner -v quiet -stats -i $InputFile -sws_flags $ScalingAlgorithm+accurate_rnd+full_chroma_int -sws_dither none `
            -vf "crop=$($Crop),colorspace=bt709:iall=bt601-6-625:fast=1,scale=$($Width):-2" `
            -minrate "$($MinRate - 128)k" -maxrate "$($MaxRate - 128)k" -b:v "$($ClipBitrate - 128)k" `
            -pix_fmt $PixelFormat -colorspace 1 -color_range 1 -color_primaries 1 -color_trc 1 `
            -tile-rows 0 -tile-columns $TileColumns -frame-parallel 0 -auto-alt-ref 1 -arnr-maxframes 7 -arnr-strength 4 -lag-in-frames 25 -g 240 -aq-mode 0 `
            -threads $Threads -deadline good -crf $CRF -profile:v $VP9_Profile -c:v libvpx-vp9 -pass 1 -passlogfile $TWOPASS_FILE -cpu-used $CPU_USED -enable-tpl 1 -row-mt 1 -an -sn -f null NUL
            
            Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
            Write-Host "Performing second pass..."

            ffmpeg -hide_banner -v quiet -stats -y -i $InputFile -sws_flags $ScalingAlgorithm+accurate_rnd+full_chroma_int -sws_dither none `
            -vf "crop=$($Crop),colorspace=bt709:iall=bt601-6-625:fast=1,scale=$($Width):-2" `
            -minrate "$($MinRate - 128)k" -maxrate "$($MaxRate - 128)k" -b:v "$($ClipBitrate - 128)k" `
            -pix_fmt $PixelFormat -color_range 1 -colorspace 1 -color_primaries 1 -color_trc 1 `
            -tile-rows 0 -tile-columns $TileColumns -frame-parallel 0 -auto-alt-ref 1 -arnr-maxframes 7 -arnr-strength 4 -lag-in-frames 25 -g 240 -aq-mode 0 `
            -threads $Threads -deadline good -crf $CRF -profile:v $VP9_Profile -c:v libvpx-vp9 -c:a libvorbis -q:a 2 -pass 2 -passlogfile $TWOPASS_FILE `
            -cpu-used $CPU_USED -enable-tpl 1 -row-mt 1 -sn -map_metadata -1 -f webm $OUTPUT_WEBM
    }
    else {
        # Check if contains subtitles
        if ($null -eq $isSubtitles)
        {
            # No subtitles
            Write-Host "No subtitles detected." -ForegroundColor Magenta

            Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
            Write-Host "Performing first pass..."
            ffmpeg -hide_banner -v quiet -stats -i $InputFile -sws_flags $ScalingAlgorithm+accurate_rnd+full_chroma_int -sws_dither none `
            -vf "crop=$($Crop),colorspace=bt709:iall=bt601-6-625:fast=1,scale=$($Width):-2" `
            -minrate "$($MinRate)k" -maxrate "$($MaxRate)k" -b:v "$($ClipBitrate)k" `
            -pix_fmt $PixelFormat -colorspace 1 -color_range 1 -color_primaries 1 -color_trc 1 `
            -tile-rows 0 -tile-columns $TileColumns -frame-parallel 0 -auto-alt-ref 1 -arnr-maxframes 7 -arnr-strength 4 -lag-in-frames 25 -g 240 -aq-mode 0 `
            -threads $Threads -deadline good -crf $CRF -profile:v $VP9_Profile -c:v libvpx-vp9 -pass 1 -passlogfile $TWOPASS_FILE -cpu-used $CPU_USED -enable-tpl 1 -row-mt 1 -an -sn -f null NUL
    
            Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
            Write-Host "Performing second pass..."
            ffmpeg -hide_banner -v quiet -stats -y -i $InputFile -sws_flags $ScalingAlgorithm+accurate_rnd+full_chroma_int -sws_dither none `
            -vf "crop=$($Crop),colorspace=bt709:iall=bt601-6-625:fast=1,scale=$($Width):-2" `
            -minrate "$($MinRate)k" -maxrate "$($MaxRate)k" -b:v "$($ClipBitrate)k" `
            -pix_fmt $PixelFormat -color_range 1 -colorspace 1 -color_primaries 1 -color_trc 1 `
            -tile-rows 0 -tile-columns $TileColumns -frame-parallel 0 -auto-alt-ref 1 -arnr-maxframes 7 -arnr-strength 4 -lag-in-frames 25 -g 240 -aq-mode 0 `
            -threads $Threads -deadline good -crf $CRF -profile:v $VP9_Profile -c:v libvpx-vp9 -pass 2 -passlogfile $TWOPASS_FILE -cpu-used $CPU_USED -enable-tpl 1 -row-mt 1 -an -sn `
            -map_metadata -1 -f webm $OUTPUT_WEBM
        }
        elseif ($isSubtitles -like "*hdmv_pgs_subtitle")
        {
            # PGS subtitles
            Write-Host "PGS subtitles detected." -ForegroundColor Magenta

            Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
            Write-Host "Performing first pass..."
            ffmpeg -hide_banner -v quiet -stats -i $InputFile -sws_flags lanczos+accurate_rnd+full_chroma_int -sws_dither none `
            -filter_complex "[0:v][0:s]overlay=eof_action=pass[v1]; [v1]crop=$($Crop),colorspace=bt709:iall=bt601-6-625:fast=1,scale=$($Width):-2[v2]" -map "[v2]" `
            -minrate "$($MinRate)k" -maxrate "$($MaxRate)k" -b:v "$($ClipBitrate)k" `
            -pix_fmt $PixelFormat -colorspace 1 -color_range 1 -color_primaries 1 -color_trc 1 `
            -tile-rows 0 -tile-columns $TileColumns -frame-parallel 0 -auto-alt-ref 1 -arnr-maxframes 7 -arnr-strength 4 -lag-in-frames 25 -g 240 -aq-mode 0 `
            -threads $Threads -deadline good -crf $CRF -profile:v $VP9_Profile -c:v libvpx-vp9 -pass 1 -passlogfile $TWOPASS_FILE -cpu-used $CPU_USED -enable-tpl 1 -row-mt 1 -an -sn -f null NUL
    
            Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
            Write-Host "Performing second pass..."
            ffmpeg -hide_banner -v quiet -stats -y -i $InputFile -sws_flags lanczos+accurate_rnd+full_chroma_int -sws_dither none `
            -filter_complex "[0:v][0:s]overlay=eof_action=pass[v1]; [v1]crop=$($Crop),colorspace=bt709:iall=bt601-6-625:fast=1,scale=$($Width):-2[v2]" -map "[v2]" `
            -minrate "$($MinRate)k" -maxrate "$($MaxRate)k" -b:v "$($ClipBitrate)k" `
            -pix_fmt $PixelFormat -color_range 1 -colorspace 1 -color_primaries 1 -color_trc 1 `
            -tile-rows 0 -tile-columns $TileColumns -frame-parallel 0 -auto-alt-ref 1 -arnr-maxframes 7 -arnr-strength 4 -lag-in-frames 25 -g 240 -aq-mode 0 `
            -threads $Threads -deadline good -crf $CRF -profile:v $VP9_Profile -c:v libvpx-vp9 -pass 2 -passlogfile $TWOPASS_FILE -cpu-used $CPU_USED -enable-tpl 1 -row-mt 1 -an -sn `
            -map_metadata -1 -f webm $OUTPUT_WEBM
        }
        else
        {
            #SRT subtitles
            Write-Host "SRT subtitles detected." -ForegroundColor Magenta

            Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
            Write-Host "Performing first pass..."
            ffmpeg -hide_banner -v quiet -stats -i $InputFile -sws_flags lanczos+accurate_rnd+full_chroma_int -sws_dither none `
            -vf "crop=$($Crop),colorspace=bt709:iall=bt601-6-625:fast=1,subtitles=$($InputFile):force_style='Fontsize=20,Alignment=2,MarginL=5,MarginV=10',scale=$($Width):-2" `
            -minrate "$($MinRate)k" -maxrate "$($MaxRate)k" -b:v "$($ClipBitrate)k" `
            -pix_fmt $PixelFormat -colorspace 1 -color_range 1 -color_primaries 1 -color_trc 1 `
            -tile-rows 0 -tile-columns $TileColumns -frame-parallel 0 -auto-alt-ref 1 -arnr-maxframes 7 -arnr-strength 4 -lag-in-frames 25 -g 240 -aq-mode 0 `
            -threads $Threads -deadline good -crf $CRF -profile:v $VP9_Profile -c:v libvpx-vp9 -pass 1 -passlogfile $TWOPASS_FILE -cpu-used $CPU_USED -enable-tpl 1 -row-mt 1 -an -sn -f null NUL
    
            Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
            Write-Host "Performing second pass..."
            ffmpeg -hide_banner -v quiet -stats -y -i $InputFile -sws_flags lanczos+accurate_rnd+full_chroma_int -sws_dither none `
            -vf "crop=$($Crop),colorspace=bt709:iall=bt601-6-625:fast=1,subtitles=$($InputFile):force_style='Fontsize=20,Alignment=2,MarginL=5,MarginV=10',scale=$($Width):-2" `
            -minrate "$($MinRate)k" -maxrate "$($MaxRate)k" -b:v "$($ClipBitrate)k" `
            -pix_fmt $PixelFormat -color_range 1 -colorspace 1 -color_primaries 1 -color_trc 1 `
            -tile-rows 0 -tile-columns $TileColumns -frame-parallel 0 -auto-alt-ref 1 -arnr-maxframes 7 -arnr-strength 4 -lag-in-frames 25 -g 240 -aq-mode 0 `
            -threads $Threads -deadline good -crf $CRF -profile:v $VP9_Profile -c:v libvpx-vp9 -pass 2 -passlogfile $TWOPASS_FILE -cpu-used $CPU_USED -enable-tpl 1 -row-mt 1 -an -sn `
            -map_metadata -1 -f webm $OUTPUT_WEBM
        }
    }
}

Write-Host "[$((Get-Date).ToString('T'))]" -NoNewline -ForegroundColor Cyan
Write-Host -NoNewline "WebM saved at "; Write-Host -ForegroundColor Green ($OUTPUT_WEBM)
Write-Host "Done in " -NoNewline -ForegroundColor DarkGreen
if ($PerformanceTime.TotalSeconds -le 60) {
    Write-Host "$([math]::Round($PerformanceTime.TotalSeconds)) " -NoNewline -ForegroundColor Green
    Write-Host "seconds." -ForegroundColor DarkGreen
} else {
    Write-Host "$($PerformanceTime.Minutes) minutes " -NoNewline -ForegroundColor Green
    Write-Host "$($PerformanceTime.Seconds) seconds ($([math]::Round($PerformanceTime.TotalSeconds))s)." -ForegroundColor Green
}

Write-Host "Cleaning up..." -ForegroundColor Cyan
Remove-Item -Path $($TWOPASS_FILE + "-0.log")
Write-Host "Done." -ForegroundColor Green