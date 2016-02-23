<#

.Synopsis

Updates a specified eRecruiter installation to the most recent version.

.Description

The script updates a eRecruiter installation in the specified folder of -parameter installationDirectory. 
The installation directory must have a "bin" folder where applications are located.
The script downloads the update package (ZIP archive) if the -parameter updatePackage is an URL. 
If the -parameter updatePackage is a local file path the updatepackage is just extracted.

.Parameter updatePackage

(Required) The path to the update package can either be an URL or a local file.

.Parameter installationDirectory

The directory of the eRecruiter installation. Usually "C:\Applications\eRecruiter".
If no directory is provided the current folder of the executed script is used.

.Notes

Version: 1.0

#>

param(
    [parameter(mandatory=$true)] [string] $updatePackage #The URL of the update package or the update package as ZIP archive
    ,[string] $installationDirectory #The path of the erecruiter installation. Usually "C:\Applications\eRecruiter\"
    )

# If no parameters are provided use current folder
if ([string]::IsNullOrEmpty($installationDirectory)) {   
    $installationDirectory = $PSScriptRoot
    Write-Host "No installation directory provided. Current folder '$($PSScriptRoot)' is used."
}

# Folder structure validation
if ((Test-Path $installationDirectory) -eq $false) {
    Write-Error "The specified folder does not exist."
    Exit
}
$applicationDirectory = Join-Path $installationDirectory "\bin\"

if ((Test-Path $applicationDirectory) -eq $false) {
    Write-Error "The applications folder '/bin' does not exist."
    Exit
}

$currentDate = Get-Date -Format yyyyMMddHHmmss
$backupDirectory = Join-Path $installationDirectory "\bak\eRecruiter_$($currentDate)"

#variables
# - installation folder names
$Api = "Api"
$eRecruiter = "eRecruiter"
$CompanyPortal = "CustomerPortal" #before Version 2 it was "CompanyPortal"
$CronWorker = "CronWorker"
$FileServer = "FileServer"
$ApplicantPortal = "ApplicantPortal" #in earlier versions it was "ResponsivePortal"
$Portal = "Portal"

# - file service name
$fileServerServiceName = "eR-MediaService" #before Version 2 it was "eR-FileServer"

# - files to ignore on deletion
$filesToIgnore = "AppSettings.config ConnectionStrings.config"

$logPath = Join-Path $installationDirectory "update.log"

# 
# END of setting area
##############################################

function Get-FrameworkVersion(){
	$ndpDirectory = 'hklm:\SOFTWARE\Microsoft\NET Framework Setup\NDP\'
	$v4Directory = "$ndpDirectory\v4\Full"
	if (Test-Path $v4Directory) {
	    $version = Get-ItemProperty $v4Directory -name Version | select -expand Version
	    return $version
	}
	Write-Error "No sufficient .NET Framework found. Exiting ..."
	Exit
}

function Download-String
{
    param($sourceUrl)

    try{ $sourceString = (New-Object System.Net.WebClient).DownloadString($sourceUrl) }
    catch { $error[0]|format-list -force } 
    return $sourceString
}

function GetRootFolder( $path ){
    return (Get-ChildItem -Path $path) | % { $_.FullName } | Select-Object -first 1
}

# copy the necessary applications to the installation directory
function CopyApplicationFolder() {
    param(
        [parameter(mandatory=$true)] [string] $sourceDir,
        [parameter(mandatory=$true)] [string] $destinationDir,
        [parameter(mandatory=$true)] [string] $folder
    )
    #robocopy (GetRootFolder $tempPackageDirectory) $applicationDirectory /MIR /Z /ETA /LOG:$logPath /XF AppSettings.config ConnectionStrings.config ReadMe.pdf /XD ApplicantPortal\App_Data\Custom Portal\Custom
# Parameter description
# MIR # Mirrors a directory tree. Deletes files in the destination, which are not available in the source anymore.
# Z   # Copies files in Restart mode. If copy process is interrupted, you can start at the interrupted point again.
# ETA # Shows the estimated time of arrival (ETA) of the copied files.
# LOG # Writes the status output to the log file (overwrites the existing log file).
# XF  # Excludes files that match the specified names or paths. Note that FileName can include wildcard characters (* and ?).
# XD  # Excludes directories that match the specified names and paths.
	robocopy (Join-Path $sourceDir $folder) (Join-Path $destinationDir $folder) /MIR /Z /LOG+:$logPath /XF $filesToIgnore /XD ./App_Data/Custom ./Portal/Custom
}

## Update-Script

Write-Host ""
Write-Host "Start updating at $(Get-Date)"
Write-Host ""

# Prerequisite -- Check .NET Framework version
########################################
$dotnetVersion = Get-FrameworkVersion
if ($dotnetVersion.StartsWith("4.6.","CurrentCultureIgnoreCase")) {
	Write-Host "Your .NET Framework version $($dotnetVersion) is sufficient."
}
else {
	Write-Error "Your .NET Framework version $($dotnetVersion) is not sufficient."
	Exit
}

Read-Host "Press any key to continue"

# Step (1) -- Backup of specified folder
########################################
Write-Host "(1) - Backup application to folder '" $backupDirectory "'"

robocopy $applicationDirectory $backupDirectory /MIR /Z /ETA /LOG+:$logPath


# Step (2) -- Downloading the source ZIP
########################################
if ((Test-Path $updatePackage) -eq $true) {
    Write-Host "(2) - Update package is a ZIP archive ... no need to download"
    $tempPackageFile = $updatePackage
}
else {
	Write-Host "(2) - Downloading the source ZIP package ..."
	$externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Download-File.ps1")
	iex $externalScript
	$tempPackageFile = Join-Path $installationDirectory "temp_source.zip"
	$tempPackageFile = Download-File $updatePackage $tempPackageFile
}


# Step (3) -- Extract the zip archive to a temporary folder
########################################
Write-Host "(3) - Extracting the source ZIP archive ..."
$tempPackageDirectory = Join-Path $installationDirectory "temp_source"
# remove existing temp folder before extracting the new one.
if (Test-Path $tempPackageDirectory) {
    Remove-Item -Recurse -Force $tempPackageDirectory | Out-Null
}
$externalScript = Download-String("https://raw.githubusercontent.com/eRecruiter/eRecruiter.PowerShell/master/tools/Extract-Zip.ps1")
iex $externalScript
Extract-Zip $tempPackageFile $tempPackageDirectory


# Step (4) -- Stop applications
########################################
Write-Host "(4) - Stopping web server (IIS) and media service ..."
#Stop web server
if (Get-Service W3SVC -ErrorAction SilentlyContinue)
{
	Stop-Service W3SVC
}
#stop the fileservice
if (Get-Service $fileServerServiceName -ErrorAction SilentlyContinue)
{
	Stop-Service $fileServerServiceName
	#net stop $fileServerServiceName | Out-Null
}


# Step (5) -- Update the applications
########################################
Write-Host "Step (5) - Update the applications ..."

$tempPackageRootDirectory = GetRootFolder $tempPackageDirectory
#Find installed folders to update
foreach ($folder in (Get-ChildItem -Path $applicationDirectory -Name -Attributes D)) {
    
   Write-Host "`tUpdating $($folder)"
   CopyApplicationFolder $tempPackageRootDirectory $applicationDirectory $folder
}
# Replace version file.
robocopy $tempPackageRootDirectory $applicationDirectory /MIR /Z /ETA /LOG+:$logPath /XF ReadMe.pdf /XD *


# Step (6) -- Start web server and media service
########################################
Write-Host "Step (6) - Start web server (IIS) and media service ..."
if (Get-Service W3SVC -ErrorAction SilentlyContinue)
{
	Start-Service W3SVC
}
if (Get-Service $fileServerServiceName -ErrorAction SilentlyContinue)
{
	Start-Service $fileServerServiceName
}


# Step (7) -- Remove temporary files
########################################
Write-Host "Step (7) - Removing temporary files ..."
Remove-Item -Recurse -Force $tempPackageFile | Out-Null
Remove-Item -Recurse -Force $tempPackageDirectory | Out-Null

Write-Host ""
Write-Host "The update is finished"
Write-Host ""
