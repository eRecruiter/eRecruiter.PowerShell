<#

.Synopsis

# Script available at https://github.com/eRecruiter/eRecruiter.Powershell

Prepares a given SQL Server database for the eRecruiter application.

.Description

Requirements:
    - eRecruiter database prepare SQL scripts which contains the DB schema and some sample data. This scripts are included in the "er-install-package.zip" file.
    - database
    - user with database access (default language "German", password never expires)   

The script prepares an existing SQL database with the schema and sample data for the eRecruiter. 
The user must have database access with the priviliges to create a database.
The user credentials only have to be provided, if the current user does not have the permissions to access the database.

.Parameter dbServer

(Optional) The path to the SQL server, which hosts the eRecruiter database. 
Usually the path looks like SERVERNAME\INSTANCENAME.
If none is provided, localhost is used.

.Parameter dbName

(Required) The name of the database to access.

.Parameter dbUserName

(Optional) The database user, who has access to the database server provided in parameter "dbName".
If none or no "dbUserPassword" is provided the current user who executes this script is used and the connection to the SQL server is made with windows authentication.
If a value is provided the connection switches to mixed-mode authentication.

.Parameter dbUserPassword

(Optional) The password of the database user provided in parameter "dbUserName".
If no value for parameter "dbUserName" is provided, this parameter is ignored.

.Parameter scriptDirectory

(Optional) The directory which contains the SQL scripts "CreateEmptySchema.sql"" and "CreateEmptyData.sql".
The scripts are found in "er-install-package.zip" file.
If no directory is provided the current directory is used. If none of the scripts is found an error is presented.

.Notes

No spaces or other special characters in the parameters please

Version: 1.0

#>

param(
    [string] $dbServer = "localhost" #SERVERNAME\INSTANCENAME
    ,[parameter(mandatory=$true)] [string] $dbName #eRecruiter_DB_Name
    ,[string] $dbUserName #eRecruiter_DB_User 
    ,[string] $dbUserPassword #eRecruiter_DB_User_Password
    ,[string] $scriptDirectory = $PSScriptRoot #directory with SQL scripts schema and empty data
    )

function CheckPath( $path ) {
    if ((Test-Path $path) -eq $false) {
        Write-Error "The folder '$path' does not exist."
        Exit
    }
}

function WriteWarning( $warningText ) {
    Write-Warning $warningText
    Write-Output $_.Exception|format-list -force
}

# Folder structure validation
Write-Host "Check scripts folder '$scriptDirectory'."
CheckPath($scriptDirectory)

#path to sql scripts (included in er-install-package.zip)
$sqlScriptForSchema = Join-Path $scriptDirectory "\CreateEmptySchema.sql"   # CreateEmptySchema.sql
$sqlScriptForEmptyData = Join-Path $scriptDirectory "\CreateEmptyData.sql"  # CreateEmptyData.sql
# Check if files exist in the script directory
CheckPath($sqlScriptForSchema)
CheckPath($sqlScriptForEmptyData)

###########################################

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$server = new-Object ('Microsoft.SqlServer.Management.Smo.Server') "$dbServer"

#If user credentials are provided, check if they are valid and sign the user in
if ([string]::IsNullOrEmpty($dbUserName) -or [string]::IsNullOrEmpty($dbUserPassword)) {
    Write-Host "Using windows integrated connection to connect sql server."
}
else {
    Write-Host "Using mixed-mode connection with provided credentials 'user: $dbUserName' to connect sql server."
    #Default connection is via Windows integrated, need to tell Powershell we do NOT want that
    $server.ConnectionContext.LoginSecure=$false; 

    $server.ConnectionContext.set_Login("$dbUserName"); 
    $server.ConnectionContext.set_Password("$dbUserPassword") 
}

# Step (1) -- Validating user credentials
#########################################
try{
    Write-Host "Validating user credentials ..."
    $server.databases | Select-Object Name  | Out-Null
    Write-Host "`tOK"  -ForegroundColor green
}
catch {
    WriteWarning "`nCould not connect to sql server - verify credentials`n"
    exit -1
}


# Step (2) -- Check if database exists
######################################
Write-Host "`nCheck if database $dbName exists ..."
$dbObject = $server.Databases[$dbName] #create SMO handle to database

if (!$dbObject)
{
    WriteWarning "`tDatabase does not exist!`n"
    exit -2
}
Write-Host "`tOK"  -ForegroundColor green


# Step (3) -- Create schema and add initial data to database
#############################################################
try
{
    Write-Host "`nCreate schema for database ..."
    Invoke-SqlCmd -InputFile $sqlScriptForSchema -ServerInstance $server -Database $dbName        
    Write-Host "`tComplete"  -ForegroundColor green

    Write-Host "`nAdd initial data to database ..."
    Invoke-SqlCmd -InputFile $sqlScriptForEmptyData -ServerInstance $server -Database $dbName        
    Write-Host "`tComplete"  -ForegroundColor green
}
catch [Exception]
{
    WriteWarning "Sql script for creating schema and/or add empty data failed!"   
}


# Step (4) -- Assign user to schema owner
#########################################
if ([string]::IsNullOrEmpty($dbUserName) -eq $false) {
    try
    {
        $schemas = @("db_owner", "ecBase", "OrderManagement")
        foreach($schema in $schemas)
        {
            Write-Host "`nSet owner for schema '$schema' ..."
            $dbSchema = $dbObject.Schemas[$schema]
            $dbSchema.Owner = $dbUserName
            $dbSchema.Alter()
            Write-Host("`tUser $dbUserName successfully own schema $dbSchema.") -ForegroundColor green
        }
    }
    catch [Exception]
    {
        WriteWarning "`nAssign user as schema owner failed!"   
        exit -4
    }

    # Step (5) -- Assign user to owner of FullTextCatalog and QuickSearchCatalog
    ############################################################################
    try
    {
        $catalogs = @("FullTextCatalog","QuickSearchCatalog")
        foreach($catalog in $catalogs)
        {
            Write-Host "`nSet owner for catalog '$catalog' ..."
            $dbCatalog = $dbObject.FullTextCatalogs[$catalog]
            $dbCatalog.Owner = $dbUserName
            $dbCatalog.Alter()
            Write-Host("`tUser $dbUserName successfully own catalog $dbCatalog.") -ForegroundColor green
        }
    }
    catch [Exception]
    {
        WriteWarning "`nAssign user as catalog owner failed!"   
        exit -5
    }
}

Write-Host "`n`n!!! Script prepare db for eRecruiter application finished !!!`n`n" -ForegroundColor green
