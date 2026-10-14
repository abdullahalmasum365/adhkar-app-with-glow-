# ==============================================================================
# scripts/scan_audio_duplicates.ps1
#
# Scans all .mp3 files in assets/audio/, calculates SHA-256 and MD5 hashes,
# groups duplicates, and highlights files with embedded PNG/JPEG artwork.
# ==============================================================================

$AudioDir = Join-Path $PSScriptRoot "..\assets\audio"
if (-not (Test-Path $AudioDir)) {
    Write-Error "Directory not found: $AudioDir"
    exit 1
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "                    SCANNING ASSETS/AUDIO FOR DUPLICATES             " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$Files = Get-ChildItem -Path $AudioDir -Filter *.mp3 -File | Sort-Object Name
Write-Host "Total MP3 files found: $($Files.Count)" -ForegroundColor Green

$Hashes = @{}
$FileDetails = @()

foreach ($File in $Files) {
    $HashSha = (Get-FileHash -Path $File.FullName -Algorithm SHA256).Hash
    $Bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    $Md5Alg = [System.Security.Cryptography.MD5]::Create()
    $Md5Hash = [System.BitConverter]::ToString($Md5Alg.ComputeHash($Bytes)).Replace("-", "").ToLower()

    # Check for embedded PNG (89 50 4E 47) or JPEG (FF D8 FF)
    $HasArt = $false
    for ($i = 0; $i -lt [Math]::Min($Bytes.Length - 4, 2048); $i++) {
        if ($Bytes[$i] -eq 0x89 -and $Bytes[$i+1] -eq 0x50 -and $Bytes[$i+2] -eq 0x4E -and $Bytes[$i+3] -eq 0x47) {
            $HasArt = $true
            break
        }
        if ($Bytes[$i] -eq 0xFF -and $Bytes[$i+1] -eq 0xD8 -and $Bytes[$i+2] -eq 0xFF) {
            $HasArt = $true
            break
        }
    }

    $Obj = [PSCustomObject]@{
        Name = $File.Name
        FullName = $File.FullName
        Length = $File.Length
        MD5 = $Md5Hash
        SHA256 = $HashSha
        HasEmbeddedArt = $HasArt
    }
    $FileDetails += $Obj

    if (-not $Hashes.ContainsKey($Md5Hash)) {
        $Hashes[$Md5Hash] = @()
    }
    $Hashes[$Md5Hash] += $Obj
}

$Duplicates = $Hashes.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | Sort-Object { $_.Value.Count } -Descending

Write-Host "`nTotal Unique Hashes: $($Hashes.Count)" -ForegroundColor Yellow
Write-Host "Total Duplicate Groups: $($Duplicates.Count)" -ForegroundColor Red
Write-Host "======================================================================`n" -ForegroundColor Cyan

$GroupNum = 1
foreach ($Group in $Duplicates) {
    $Md5 = $Group.Key
    $Items = $Group.Value
    $First = $Items[0]
    $SizeKb = [Math]::Round($First.Length / 1KB, 1)

    Write-Host "[$GroupNum] MD5: $Md5 | Size: $SizeKb KB" -ForegroundColor Yellow
    foreach ($Item in $Items) {
        $ArtNote = if ($Item.HasEmbeddedArt) { " [!] EMBEDDED ARTWORK FOUND" } else { "" }
        Write-Host "    -> $($Item.Name)$ArtNote" -ForegroundColor White
    }
    $GroupNum++
}

Write-Host "`nScan complete. All duplicates listed above." -ForegroundColor Green
