# ==============================================================================
# scripts/compress_audio_ffmpeg.ps1
#
# Batch compresses all MP3 files in assets/audio/ using ffmpeg:
#   1. Strips embedded artwork (-vn)
#   2. Clears ID3 tags (-map_metadata -1)
#   3. Downmixes to mono (-ac 1)
#   4. Re-encodes at 64kbps CBR (-b:a 64k) with 44.1 kHz sample rate (-ar 44100)
# ==============================================================================

param(
    [switch]$DryRun
)

$AudioDir = Join-Path $PSScriptRoot "..\assets\audio"
$BackupDir = Join-Path $PSScriptRoot "..\assets\audio_backup_original"

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg is not found on your PATH. Please install ffmpeg."
    exit 1
}

$Files = Get-ChildItem -Path $AudioDir -Filter *.mp3 -File | Sort-Object Name
Write-Host "Found $($Files.Count) MP3 files in $AudioDir" -ForegroundColor Cyan

if (-not $DryRun -and -not (Test-Path $BackupDir)) {
    Write-Host "Creating backup in $BackupDir..." -ForegroundColor Yellow
    Copy-Item -Path $AudioDir -Destination $BackupDir -Recurse
}

$TotalOrig = 0
$TotalNew = 0
$TmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

try {
    $i = 1
    foreach ($File in $Files) {
        $OrigSize = $File.Length
        $TotalOrig += $OrigSize
        $OutPath = Join-Path $TmpDir $File.Name

        # Run ffmpeg
        $ArgsList = @(
            "-y",
            "-i", $File.FullName,
            "-vn",
            "-map_metadata", "-1",
            "-ac", "1",
            "-b:a", "64k",
            "-ar", "44100",
            $OutPath
        )

        & ffmpeg $ArgsList 2>$null

        if (Test-Path $OutPath) {
            $NewSize = (Get-Item $OutPath).Length
            $TotalNew += $NewSize
            $Pct = [Math]::Round((1 - ($NewSize / $OrigSize)) * 100, 1)
            $OrigKb = [Math]::Round($OrigSize / 1KB, 1)
            $NewKb = [Math]::Round($NewSize / 1KB, 1)

            Write-Host ("[{0,3}/{1}] {2,-38} | {3,6} KB -> {4,5} KB ({5,4}% saved)" -f $i, $Files.Count, $File.Name, $OrigKb, $NewKb, $Pct)

            if (-not $DryRun) {
                Copy-Item -Path $OutPath -Destination $File.FullName -Force
            }
        } else {
            Write-Warning "Failed to compress $($File.Name)"
            $TotalNew += $OrigSize
        }
        $i++
    }
}
finally {
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

$SavedMb = [Math]::Round(($TotalOrig - $TotalNew) / 1MB, 2)
$OrigMb = [Math]::Round($TotalOrig / 1MB, 2)
$NewMb = [Math]::Round($TotalNew / 1MB, 2)

Write-Host "`n=======================================================" -ForegroundColor Green
Write-Host "SUMMARY" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "Original Size:   $OrigMb MB"
Write-Host "Compressed Size: $NewMb MB"
Write-Host "Total Saved:     $SavedMb MB"
Write-Host "=======================================================`n"
