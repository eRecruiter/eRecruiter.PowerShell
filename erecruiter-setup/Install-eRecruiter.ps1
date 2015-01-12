# The name of the customer, to enable more than one eRecruiter installation on a single server
# No spaces or other special characters please
$customerName = "Customer_Name"

# The URL to the ZIP package that contains the application source
$sourceUrl = "http://staging.epunkt.net/eRecruiter.zip"

# The directory to install the applications to
# WARNING: All existing files in this directory will be deleted!
$installationDirectory = "c:\Applications\$customerName"

# Whether or not to install the FileServer (PDF & video) service and CronWorker (maintainance) task
$includeFileServer = $false
$includeCronWorker = $false

# The windows user credentials
# These are used to run the IIS applications and the CronWorker windows task
$username = "DOMAIN\User"
$password = "p4ssWord!"

# The eRecruiter settings
$eRecruiter_ConnectionString = "Data Source=.\;Initial Catalog=$customerName-eRecruiter;Integrated Security=True;"
$eRecruiter_FilesDirectory = "c:\Data\Files"
$eRecruiter_TemplatesDirectory = "c:\Data\Templates"



# This function is called down below, but I moved it up here because it contains a lot of configuration
# And it would be cumbersome to put all this configuration into dozenns of variables
function Configure-IIS-Bindings() {
    $cert = "88 AA AA AA AA AA BB BB BB DE AD 87 6d d9 c5 d5 96 6a f0 ff".Replace(" ", "").ToUpper()

    Set-Http-And-Https-Binding "$customerName-eRecruiter" "10.1.1.1" "$customerName.erecruiter.net" $cert
    Set-Http-And-Https-Binding "$customerName-Api" "10.1.1.1" "$customerName-api.erecruiter.net" $cert
    Set-Http-And-Https-Binding "$customerName-Portal" "10.1.1.2" "$customerName.kandidatenportal.eu" $cert
    Set-Http-And-Https-Binding "$customerName-Responsive-Portal" "10.1.1.2" "$customerName-responsive.kandidatenportal.eu" $cert
    Set-Http-And-Https-Binding "$customerName-CompanyPortal" "10.1.1.1" "$customerName-portal.erecruiter.net" $cert
}


# This function is also called down below
# Use it to configure additional settings that are not set per-default down below
function Configure-eRecruiter-Settings() {
    Set-AppSetting-Recursive "FileServerHost" "PDF_SERVER"
    Set-AppSetting-Recursive "SmtpHost" "SMTP_SERVER"
    Set-AppSetting-Recursive "RequireSsl" "true"

    Set-AppSetting-Recursive "Portal-MandatorId" "1" ".\Portal"

    Set-AppSetting-Recursive "MandatorId" "1" ".\Responsive-Portal"
    Set-AppSetting-Recursive "ApiEndpoint" "some_url" ".\Responsive-Portal"
    Set-AppSetting-Recursive "ApiKey" "some_key" ".\Responsive-Portal"
    Set-AppSetting-Recursive "CustomFolder_$customerName-responsive.kandidatenportal.eu" "$customerName" ".\Responsive-Portal"
}



Write-Host "Good day to you. Checking your privileges ..."
iex (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Check-Elevation.ps1")
Check-Elevation-And-Exit-If-Necessary



Write-Host "Validating user credentials ..."
iex (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Check-Credentials.ps1")
Check-Credentials-And-Exit-If-Necessary $username $password



Write-Host "Installing necessary IIS/ASP.NET modules ..."
Import-Module ServerManager
# this also installs a lot of dependencies
Add-WindowsFeature -Name Web-Asp-Net45,Web-Mgmt-Console,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Http-Logging,Web-Stat-Compression | Out-Null



Write-Host "Downloading the source ZIP package ..."
$tempPackageFile = Join-Path $installationDirectory "temp_source.zip"
Invoke-WebRequest $sourceUrl -OutFile $tempPackageFile
if ((Test-Path $tempPackageFile) -eq $false) {
    Write-Host "Download failed, make your your internet connection is working. Exiting ..." -ForegroundColor Yellow
    exit -3
}




Write-Host "Creating installation directory ..."
New-Item -ItemType Directory -Force -Path $installationDirectory | Out-Null
Set-Location $installationDirectory



Write-Host "Unzipping the source ZIP package ..."
$tempPackageDirectory = Join-Path $installationDirectory "temp_source"
if (Test-Path $tempPackageDirectory) {
    Remove-Item -Recurse -Force $tempPackageDirectory | Out-Null
}
iex (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Extract-Zip.ps1")
Extract-Zip $tempPackageFile $tempPackageDirectory



Write-Host "Stopping IIS and removing existing applications ..."
net stop W3SVC | Out-Null
$applicationsDirectory = (Join-Path $installationDirectory "/Bin")
if (Test-Path $applicationsDirectory) {
    if (Get-Service "eR-FileServer" -ErrorAction SilentlyContinue)
    {
        net stop "eR-FileServer" | Out-Null
        sc.exe delete "eR-FileServer" | Out-Null
    }
    Remove-Item -Recurse -Force $applicationsDirectory | Out-Null
}



Write-Host "Copying applications ..."
New-Item -ItemType Directory -Force -Path $applicationsDirectory | Out-Null
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "CronWorker" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "CompanyPortal" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "Portal" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "eRecruiter" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "Api" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "Responsive-Portal" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse



if ($includeFileServer) {
    $tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "FileServer" -Recurse) | % { $_.FullName } | Select-Object -first 1
    Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse

    Write-Host "Installing FileServer service ..."
    $fileServerExecuteablePath = Join-Path $applicationsDirectory "FileServer/ePunkt.FileServer.exe"
    sc.exe create "eR-FileServer" Binpath= "$fileServerExecuteablePath service=true" DisplayName= "eRecruiter FileServer" start= auto | Out-Null
    net start "eR-FileServer" | Out-Null
}



if ($includeCronWorker) {
    Write-Host "Installing CronWorker task ..."
    iex (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Create-Windows-Task.ps1")
    Grant-Logon-As-Batch-Job ($username) | Out-Null
    $cronWorkerExecuteablePath = Join-Path $applicationsDirectory "CronWorker/ePunkt.CronWorker.exe"
    Create-Windows-Task-That-Runs-Every-15-Minutes "eRecruiter CronWorker" "$cronWorkerExecuteablePath" "" $username $password | Out-Null
}



Write-Host "Configuring IIS ..."
iex (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Configure-IIS-Website.ps1")
function Create-Application-Internal($name) {
    $applicationPath = Join-Path $applicationsDirectory "$name"
    $logPath = Join-Path $installationDirectory "Logs/$name"
	New-Item -ItemType Directory -Force -Path $logPath | Out-Null
    Create-AppPool-And-Website "$customerName-$name" $applicationPath $logPath $username $password
}
Create-Application-Internal("eRecruiter") | Out-Null
Create-Application-Internal("Api") | Out-Null
Create-Application-Internal("Portal") | Out-Null
Create-Application-Internal("Responsive-Portal") | Out-Null
Create-Application-Internal("CompanyPortal") | Out-Null
Configure-IIS-Bindings | Out-Null



Write-Host "Configuring eRecruiter database connection string ..."
iex (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Configure-eRecruiter.ps1")
Set-Location $applicationsDirectory
Create-Empty-ConnectionStrings-If-Not-Exists "CompanyPortal" | Out-Null
Create-Empty-ConnectionStrings-If-Not-Exists "eRecruiter" | Out-Null
Create-Empty-ConnectionStrings-If-Not-Exists "CronWorker" | Out-Null
Create-Empty-ConnectionStrings-If-Not-Exists "Api" | Out-Null
Create-Empty-ConnectionStrings-If-Not-Exists "Portal" | Out-Null
Create-Empty-ConnectionStrings-If-Not-Exists "Responsive-Portal" | Out-Null
Set-ConnectionString-Recursive $eRecruiter_ConnectionString | Out-Null



Write-Host "Configuring eRecruiter settings ..."
Create-Empty-AppSettings-If-Not-Exists "CompanyPortal" | Out-Null
Create-Empty-AppSettings-If-Not-Exists "eRecruiter" | Out-Null
Create-Empty-AppSettings-If-Not-Exists "CronWorker" | Out-Null
Create-Empty-AppSettings-If-Not-Exists "Api" | Out-Null
Create-Empty-AppSettings-If-Not-Exists "Portal" | Out-Null
Create-Empty-AppSettings-If-Not-Exists "Responsive-Portal" | Out-Null

Set-AppSetting-Recursive "WebBasePath" (Join-Path $applicationsDirectory "eRecruiter") | Out-Null
Set-AppSetting-Recursive "WindowsFileManager_FilesPath" $eRecruiter_FilesDirectory | Out-Null
Set-AppSetting-Recursive "WindowsFileManager_TemplatesPath" $eRecruiter_TemplatesDirectory | Out-Null
$tempPath = Join-Path $installationDirectory "Temp"
New-Item -ItemType Directory -Force -Path $tempPath | Out-Null
Set-AppSetting-Recursive "TemporaryFileManager_Path" $tempPath | Out-Null
Set-AppSetting-Recursive "FileServerHost" "localhost" | Out-Null
Set-AppSetting-Recursive "SmtpHost" "localhost" | Out-Null
Set-AppSetting-Recursive "RequireSsl" "false" | Out-Null
Set-AppSetting-Recursive "GoogleMapsApiKey" "ABQIAAAAnOKm6VDu6bCBZXPmN9EkrxRm1_h-rqQCrkx63hPUdnka_uoe5hSl6KVXRVNExqskEmBuuBUCt1OABA" | Out-Null

# Remove settings from the responsive-portal, because we don't need it there anyways
Set-AppSetting-Recursive "WebBasePath" $null ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "WindowsFileManager_FilesPath" $null ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "WindowsFileManager_TemplatesPath" $null ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "TemporaryFileManager_Path" $null ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "FileServerHost" $null ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "SmtpHost" $null ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "RequireSsl" $null ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "GoogleMapsApiKey" $null ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "ClientValidationEnabled" "true" ".\Responsive-Portal" | Out-Null
Set-AppSetting-Recursive "UnobtrusiveJavaScriptEnabled" "true" ".\Responsive-Portal" | Out-Null

Configure-eRecruiter-Settings | Out-Null


Write-Host "Starting IIS ..."
net start W3SVC | Out-Null



Write-Host "Removing temporary files ..."
Remove-Item -Recurse -Force $tempPackageFile | Out-Null
Remove-Item -Recurse -Force $tempPackageDirectory | Out-Null



Write-Host "Everything done. Have a nice day."
