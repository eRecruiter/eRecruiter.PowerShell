function Set-Directory-Permission
{
    param($directory, $accessRule)

    if (Test-Path $directory) {
        try{
            $Acl = Get-Acl $directory
            $Acl.SetAccessRule($accessRule)
            Write-Host "OK"  -ForegroundColor green
            return
        }
        catch {
            Write-Warning "Error setting access rule!"
            return
        }
    }
    Write-Warning "Directory not exists!"
}