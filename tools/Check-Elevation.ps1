function Check-Elevation-And-Exit-If-Necessary() {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $identity
	if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $false) {
		Write-Host "Administrative (elevated) privileges are required. Exiting ..." -ForegroundColor Yellow
		exit -1
	}
}
