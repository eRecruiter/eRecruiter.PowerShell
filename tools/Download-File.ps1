function Download-File
{
    param($sourceUrl, $tempOutFile)

    Invoke-WebRequest $sourceUrl -OutFile $tempOutFile
    if ((Test-Path $tempOutFile) -eq $false) {
        Write-Host "Download from $sourceUrl failed, make your your internet connection is working. Exiting ..." -ForegroundColor Yellow
        exit -3
    }
    return $tempOutFile
}