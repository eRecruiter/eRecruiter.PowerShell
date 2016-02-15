# copied from https://github.com/eRecruiter/eRecruiter.PowerShell
#
# Requirements:
#      - database and database user 
#
# Enter and set your options below!!!!
# 
##############################################


# The sql server variables and credentials
$databaseServer = "PathToServer\SqlServerName" #SERVERNAME\INSTANCENAME
$databaseName = "eRecruiter"
$databaseUser = "eRecruiter"
$databasePassword = "TypePasswordHere"


# The windows user credentials
# These are used to run the IIS applications and the CronWorker windows task
$username = "TypeUsernameHere"
$password = "TypePasswordHere"

# The URL to the ZIP package that contains the application source
$sourceUrl = "......eRecruiter.zip"

# The URL to the ZIP package that contains the templates and other necessary stuff
$peripheryDataUrl = "......er-install-package.zip"

# The directory to install the applications to
# WARNING: All existing files in this directory will be deleted!
$installationDirectory = "c:\eRecruiter"

# Whether or not to install the FileServer (PDF & video) service, CronWorker (maintenance) task, 
# templates and iFilter packages
$includeFileServer = $true
$includeCronWorker = $true
$includeTemplates = $true
$includeiFilter = $true
$includeNonResponsivePortal = $false
$addWebsitesToIIS = $true #set to false if you want to update eRecruiter Application

# The eRecruiter settings
# example for integrated security: "Data Source=DB_SERVER,41433;Initial Catalog=$databaseName;Integrated Security=True;"
$eRecruiter_ConnectionString = "Data Source=$databaseServer;Initial Catalog=$databaseName;Persist Security Info=True;User ID=$databaseUser;Password=$databasePassword"

$dataDirectory = "c:\eRecruiter\Data" #\\ServerName\ShareName"
# Data directory will be automatically extended with a folder for templates and a folder for files
$eRecruiter_TemplatesDirectory = (Join-Path $dataDirectory "/Templates")
$eRecruiter_FilesDirectory = (Join-Path $dataDirectory "/Files")

# Enter url for API here
$apiEndpoint = "https://api.erecruiter.net"

# This function is also called down below
# Use it to configure additional settings that are not set per-default down below
function Configure-eRecruiter-Settings() {
    Set-AppSetting-Recursive "FileServerHost" "??-TypeFileServerHostHere-??"
    #Set-AppSetting-Recursive "FileServerPort" "35791"  #default port '35791' is used if not set

    Set-AppSetting-Recursive "SmtpHost" "??-TypeSmtpServerHostHere-??"
    #Set-AppSetting-Recursive "SmtpPort" "??-TypeSmtpServerPortHere-??" #default port '25' is used if not set
    #Set-AppSetting-Recursive "SmtpUseSsl" "??-TypeSmtpUseSslHere-??" #default 'false' will be used if not set
    Set-AppSetting-Recursive "SmtpSender" "??-TypeSmtpSenderHere-??"
    #Set-AppSetting-Recursive "SmtpUserName" "??-TypeSmtpUsernameHere-??"
    #Set-AppSetting-Recursive "SmtpPassword" "??-TypeSmtpPasswordHere-??"

    Set-AppSetting-Recursive "RequireSsl" "true"
    #Set-AppSetting-Recursive "Portal-MandatorId" "1" ".\Portal"
    Set-AppSetting-Recursive "MandatorId" "1" ".\ApplicantPortal"
    Set-AppSetting-Recursive "ApiEndpoint" "$apiEndpoint/api" ".\ApplicantPortal"
    Set-AppSetting-Recursive "ApiKey" "??-TypeApiKeyHere-??" ".\ApplicantPortal"
}


# 
# END of setting area
##############################################


function Download-String
{
    param($sourceUrl)

    try{ $sourceString = (New-Object System.Net.WebClient).DownloadString($sourceUrl) }
    catch { $error[0]|format-list -force } 
    return $sourceString
}


# Step (1) -- Checking privileges
#################################
Write-Host "(1) Good day to you. Checking your privileges ..."
$externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Check-Elevation.ps1")
iex $externalScript
Check-Elevation-And-Exit-If-Necessary


# Step (2) -- Validating user credentials
#########################################
Write-Host "(2) Validating user credentials ..."
$externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Check-Credentials.ps1")
iex $externalScript 
Check-Credentials-And-Exit-If-Necessary $username $password


# Step (3) -- Installing IIS/ASP.NET modules
############################################
Write-Host "(3) Installing necessary IIS/ASP.NET modules ..."
Import-Module ServerManager
# this also installs a lot of required dependencies (like IIS itself)
Add-WindowsFeature -Name Web-Asp-Net45,Web-Mgmt-Console,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Http-Logging,Web-Stat-Compression | Out-Null


# Step (4) -- Creating installation directory
#############################################
Write-Host "(4) Creating installation directory ..."
New-Item -ItemType Directory -Force -Path $installationDirectory | Out-Null
Set-Location $installationDirectory


# Step (5) -- Downloading the source ZIP
########################################
Write-Host "(5) Downloading the source ZIP package ..."
$externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Download-File.ps1")
iex $externalScript
$tempPackageFile = Join-Path $installationDirectory "temp_source.zip"
$tempPackageFile = Download-File $sourceUrl $tempPackageFile


# Step (6) -- Unzipping source ZIP
##################################
Write-Host "(6) Unzipping the source ZIP package ..."
$tempPackageDirectory = Join-Path $installationDirectory "temp_source"
if (Test-Path $tempPackageDirectory) {
    Remove-Item -Recurse -Force $tempPackageDirectory | Out-Null
}
$externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Extract-Zip.ps1")
iex $externalScript
Extract-Zip $tempPackageFile $tempPackageDirectory
# if there is a root "eRecruiter" directory in the extracted folder, remove it
$tempPackageRootDirectory = Join-Path $tempPackageDirectory "eRecruiter"
if (Test-Path $tempPackageRootDirectory) {
	Rename-Item $tempPackageRootDirectory "tmp"
	$tempPackageRootDirectory = Join-Path $tempPackageDirectory "tmp"
	Move-Item $tempPackageRootDirectory\* $tempPackageDirectory
	Remove-Item -Force $tempPackageRootDirectory
}


# Step (7) -- Stopping IIS and removing existing applications from filesystem
#############################################################################
Write-Host "(7) Stopping IIS and removing existing applications ..."
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


# Step (8) -- Copying applications to applications directory
############################################################
Write-Host "(8) Copying applications ..."
New-Item -ItemType Directory -Force -Path $applicationsDirectory | Out-Null

Write-Host "`t a) CronWorker"
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "CronWorker" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse

Write-Host "`t b) CustomerPortal"
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "CustomerPortal" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse

if($includeNonResponsivePortal){
    Write-Host "`t c) Portal"
    $tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "Portal" -Recurse) | % { $_.FullName } | Select-Object -first 1
    Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse
}

Write-Host "`t d) eRecruiter"
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "eRecruiter" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse

Write-Host "`t e) Api"
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "Api" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse

Write-Host "`t f) ApplicantPortal"
$tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "ApplicantPortal" -Recurse) | % { $_.FullName } | Select-Object -first 1
Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse


# Step (9) -- install eRecruiter file server
############################################
if ($includeFileServer) {
    $tempPath = (Get-ChildItem -Path $tempPackageDirectory -Filter "FileServer" -Recurse) | % { $_.FullName } | Select-Object -first 1
    Copy-Item -path $tempPath -destination $applicationsDirectory -Recurse

    Write-Host "(9) Installing FileServer service ..."
    $fileServerExecuteablePath = Join-Path $applicationsDirectory "FileServer/ePunkt.FileServer.exe"
    sc.exe create "eR-FileServer" Binpath= "$fileServerExecuteablePath service=true" DisplayName= "eRecruiter FileServer" start= auto | Out-Null
    net start "eR-FileServer" | Out-Null
}


# Step (10) -- install CronWorker task
#####################################
if ($includeCronWorker) {
    Write-Host "(10) Installing CronWorker task ..."
    $externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Create-Windows-Task.ps1")
    iex $externalScript
    Grant-Logon-As-Batch-Job ($username) | Out-Null
    $cronWorkerExecuteablePath = Join-Path $applicationsDirectory "CronWorker/ePunkt.CronWorker.exe"
    Create-Windows-Task-That-Runs-Every-15-Minutes "eRecruiter CronWorker" "$cronWorkerExecuteablePath" "" $username $password | Out-Null
}


# Step (11) -- install templates and/or iFilter
###############################################
if($includeTemplates -or $includeiFilter){
    Write-Host "(11) Downloading the periphery ZIP package ..."
    $tempPeripheryPackageFile = Join-Path $installationDirectory "temp_periphery.zip"
    $tempPeripheryPackageFile = Download-File $peripheryDataUrl $tempPeripheryPackageFile

    Write-Host "`ta) Unzipping the periphery ZIP package"
    $tempPeripheryPackageDirectory = Join-Path $installationDirectory "temp_periphery"
    if (Test-Path $tempPeripheryPackageDirectory) {
        Remove-Item -Recurse -Force $tempPeripheryPackageDirectory #| Out-Null
    }
    
    Extract-Zip $tempPeripheryPackageFile $tempPeripheryPackageDirectory

    if($includeTemplates){
        Write-Host "`tb) Creating templates directory"
        if (Test-Path $eRecruiter_TemplatesDirectory) {        
            Remove-Item -Recurse -Force $eRecruiter_TemplatesDirectory | Out-Null
        }
        New-Item -ItemType Directory -Force -Path $eRecruiter_TemplatesDirectory | Out-Null

        Write-Host "`tc) Copying templates"
        $tempPath = (Get-ChildItem -Path $tempPeripheryPackageDirectory -Filter "_templates" -Recurse) | % { $_.FullName } | Select-Object -first 1
        Copy-Item -path $tempPath\* -destination $eRecruiter_TemplatesDirectory -Recurse
    }

    if($includeiFilter){
        $tempPath = (Get-ChildItem -Path $tempPeripheryPackageDirectory -Filter "_install" -Recurse) | % { $_.FullName } | Select-Object -first 1
        
        Write-Host -NoNewline "`td) Running the Adobe PDF iFilter installer"

        $proc = Start-Process C:\Windows\System32\msiexec.exe " /passive /i `"$tempPath\Adobe PDF iFilter-64bit.msi`"" -wait -ErrorVariable err -ErrorAction "SilentlyContinue" 
        # $LASTEXITCODE - Contains the exit code of the last Win32 executable execution
        if ($LASTEXITCODE -eq "0")
        {
            Write-Host "`tInstallation sucessful" -foregroundcolor Green
        }
        else
        {
            Write-Error "`tInstalled with following error code: $LastExitCode). Details: $err" 
        }        

        Write-Host -NoNewline "`te) Running the Microsoft iFilter installer"
        $exe = "Microsoft iFilterPack64bit.exe"

        $proc = Start-Process -FilePath $tempPath\$exe -ArgumentList "/quiet" -wait -ErrorVariable err -ErrorAction "SilentlyContinue" 
        # $LASTEXITCODE - Contains the exit code of the last Win32 executable execution
        if ($LASTEXITCODE -eq "0")
        {
            Write-Host "`tInstallation sucessful" -foregroundcolor Green
        }
        else
        {
            Write-Error "`tInstalled with following error code: $LastExitCode). Details: $err" 
        }

        Write-Host -NoNewline "`tf) Running the Microsoft iFilter SP1 installer"
        $exe = "Microsoft iFilterpack-SP1.exe"

        $proc = Start-Process -FilePath $tempPath\$exe -ArgumentList "/quiet" -wait -ErrorVariable err -ErrorAction "SilentlyContinue" 
        # $LASTEXITCODE - Contains the exit code of the last Win32 executable execution
        if ($LASTEXITCODE -eq "0")
        {
            Write-Host "`tInstallation sucessful" -foregroundcolor Green
        }
        else
        {
            Write-Error "`tInstalled with following error code: $LastExitCode). Details: $err" 
        }
    }
}


# Step (12) -- Create files directory if not exists
##################################################
Write-Host "(12) Create files directory (if not exists) ..."
if ((Test-Path $eRecruiter_FilesDirectory) -eq $false) {
    New-Item -ItemType Directory -Force -Path $eRecruiter_FilesDirectory | Out-Null
}


# Step (13) -- Create AppPool and websites
##########################################
if($addWebsitesToIIS){
    Write-Host "(13) Configuring IIS ..."
    $externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Configure-IIS-Website.ps1")
    iex $externalScript
    function Create-Application-Internal($name) {
        $applicationPath = Join-Path $applicationsDirectory "$name"
        $logPath = Join-Path $installationDirectory "Logs/$name"
	    New-Item -ItemType Directory -Force -Path $logPath | Out-Null
        Create-AppPool-And-Website $name $applicationPath $logPath $username $password
    }
    Create-Application-Internal("eRecruiter") | Out-Null
    Create-Application-Internal("Api") | Out-Null
    if($includeNonResponsivePortal){
        Create-Application-Internal("Portal") | Out-Null
    }
    Create-Application-Internal("ApplicantPortal") | Out-Null
    Create-Application-Internal("CustomerPortal") | Out-Null
}


# Step (14) -- Configuring eRecruiter database connection string
################################################################
Write-Host "(14) Configuring eRecruiter database connection string ..."
$externalScript = Download-String ("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Configure-eRecruiter.ps1")
iex $externalScript
Set-Location $applicationsDirectory
Create-Empty-ConnectionStrings-If-Not-Exists "CustomerPortal" | Out-Null
Create-Empty-ConnectionStrings-If-Not-Exists "eRecruiter" | Out-Null
Create-Empty-ConnectionStrings-If-Not-Exists "CronWorker" | Out-Null
Create-Empty-ConnectionStrings-If-Not-Exists "Api" | Out-Null
if($includeNonResponsivePortal){
    Create-Empty-ConnectionStrings-If-Not-Exists "Portal" | Out-Null
}
Create-Empty-ConnectionStrings-If-Not-Exists "ApplicantPortal" | Out-Null
Set-ConnectionString-Recursive $eRecruiter_ConnectionString | Out-Null


# Step (15) -- Configuring eRecruiter settings
##############################################
Write-Host "(15) Configuring eRecruiter settings ..."
Create-Empty-AppSettings-If-Not-Exists "CustomerPortal" | Out-Null
Create-Empty-AppSettings-If-Not-Exists "eRecruiter" | Out-Null
Create-Empty-AppSettings-If-Not-Exists "CronWorker" | Out-Null
Create-Empty-AppSettings-If-Not-Exists "Api" | Out-Null
if($includeNonResponsivePortal){
    Create-Empty-AppSettings-If-Not-Exists "Portal" | Out-Null
}
Create-Empty-AppSettings-If-Not-Exists "ApplicantPortal" | Out-Null

Set-AppSetting-Recursive "WebBasePath" (Join-Path $applicationsDirectory "eRecruiter") | Out-Null
Set-AppSetting-Recursive "WindowsFileManager_FilesPath" $eRecruiter_FilesDirectory | Out-Null
Set-AppSetting-Recursive "WindowsFileManager_TemplatesPath" $eRecruiter_TemplatesDirectory | Out-Null
$tempDirectory = Join-Path $installationDirectory "Temp"
New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null
Set-AppSetting-Recursive "TemporaryFileManager_Path" $tempDirectory | Out-Null
Set-AppSetting-Recursive "FileServerHost" "localhost" | Out-Null
Set-AppSetting-Recursive "SmtpHost" "localhost" | Out-Null
Set-AppSetting-Recursive "RequireSsl" "false" | Out-Null
Set-AppSetting-Recursive "GoogleMapsApiKey" "ABQIAAAAnOKm6VDu6bCBZXPmN9EkrxRm1_h-rqQCrkx63hPUdnka_uoe5hSl6KVXRVNExqskEmBuuBUCt1OABA" | Out-Null


# Step (16) -- Remove not necessary settings from the responsive-portal
#######################################################################
Write-Host "(16) Remove not necessary settings from the responsive-portal ..." 
Set-AppSetting-Recursive "WebBasePath" $null ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "WindowsFileManager_FilesPath" $null ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "WindowsFileManager_TemplatesPath" $null ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "TemporaryFileManager_Path" $null ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "FileServerHost" $null ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "SmtpHost" $null ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "RequireSsl" $null ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "GoogleMapsApiKey" $null ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "ClientValidationEnabled" "true" ".\ApplicantPortal" | Out-Null
Set-AppSetting-Recursive "UnobtrusiveJavaScriptEnabled" "true" ".\ApplicantPortal" | Out-Null

Configure-eRecruiter-Settings | Out-Null


# Step (17) -- Add folder permission for IIS_IUSRS group
########################################################
Write-Host "(17) Add folder permission for IIS_IUSRS group ..."
$externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Set-Directory-Permission.ps1")
iex $externalScript

$ar = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")

Write-Host -NoNewline "`ta) Bin`t"
Set-Directory-Permission $applicationsDirectory $ar

Write-Host -NoNewline "`tb) Data`t"
Set-Directory-Permission $dataDirectory $ar

Write-Host -NoNewline "`tc) Temp`t"
Set-Directory-Permission $tempDirectory $ar

Write-Host -NoNewline "`td) Logs`t"
Set-Directory-Permission (Join-Path $installationDirectory "/Logs") $ar


# Step (18) -- Starting IIS
###########################
Write-Host "(18) Starting IIS ..."
net start W3SVC | Out-Null


# Step (19) -- Removing temporary files
#######################################
Write-Host "(19) Removing temporary files ..."
Remove-Item -Recurse -Force $tempPackageFile | Out-Null
Remove-Item -Recurse -Force $tempPackageDirectory | Out-Null
Remove-Item -Recurse -Force $tempPeripheryPackageFile | Out-Null
Remove-Item -Recurse -Force $tempPeripheryPackageDirectory | Out-Null

# go back one directory, to end where we started
cd..
Write-Host "`nEverything done. Have a nice day.`n`n" -ForegroundColor green