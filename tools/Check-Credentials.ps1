function Check-Credentials-And-Exit-If-Necessary {
    param(
        	[parameter(mandatory=$true)] [string] $username,
		[parameter(mandatory=$true)] [string] $password
	)

	Add-Type -AssemblyName System.DirectoryServices.AccountManagement
	$principalContext = "Machine"
	if ($username.Contains("@") -or $username.Contains("\")) {
		$principalContext = "Domain"
	}
	$principal = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($principalContext)
	if ($principal.ValidateCredentials($username, $password) -eq $false) {
		Write-Host "Specified credentials for $username invalid. Exiting ..." -ForegroundColor Yellow
		exit -2
	}
}
