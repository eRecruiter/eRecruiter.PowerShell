# based on script written by Ingo Karstein, https://gallery.technet.microsoft.com/PowerShell-script-to-add-b005e0f6

function Grant-Logon-As-Batch-Job ($user) {
    $policy = "SeBatchLogonRight"

    $sidstr = $null
    try {
	    $ntprincipal = new-object System.Security.Principal.NTAccount "$user"
	    $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	    $sidstr = $sid.Value.ToString()
    } catch {
	    $sidstr = $null
    }

    Write-Host "Account: $($user)."

    if ([string]::IsNullOrEmpty($sidstr)) {
	    Write-Host "Account not found."
	    exit -1
    }

    Write-Host "Account SID: $($sidstr)."

    $tmp = [System.IO.Path]::GetTempFileName()
    Write-Host "Exporting current Local Security Policy ..."
    secedit.exe /export /cfg "$($tmp)" 

    $c = Get-Content -Path $tmp 
    $currentSetting = ""

    foreach ($s in $c) {
	    if( $s -like "$policy*") {
		    $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		    $currentSetting = $x[1].Trim()
	    }
    }

    if ($currentSetting -notlike "*$($sidstr)*") {
	    Write-Host "Modifying setting 'Logon as Batch Job' ..."
	
	    if ([string]::IsNullOrEmpty($currentSetting)) {
		    $currentSetting = "*$($sidstr)"
	    } else {
		    $currentSetting = "*$($sidstr),$($currentSetting)"
	    }
	
	    Write-Host "$currentSetting"
	
	$outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
$policy = $($currentSetting)
"@
	    $tmp2 = [System.IO.Path]::GetTempFileName()

	    Write-Host "Importing new settings to Local Security Policy ..."
	    $outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force

	    Push-Location (Split-Path $tmp2)
	
	    try {
		    secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS 
	    } finally {	
		    Pop-Location
	    }
    } else {
	    Write-Host "Account already in 'Logon as Batch Job'."
    }

    Write-Host "Done."
}