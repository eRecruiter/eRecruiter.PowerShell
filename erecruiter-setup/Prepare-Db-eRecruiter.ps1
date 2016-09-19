<#

.Synopsis

Prepares a given SQL Server database for the eRecruiter application.

.Description

# Requirements:
#   - eRecruiter database prepare SQL script which contains the DB schema and some sample data. This scripts are included in the "er-install-package.zip" file.
#   - database
#   - user with database access (default language "German", password never expires)   

The script prepares an existing SQL database with the schema and sample data for the eRecruiter. 
The user must have database access with the priviliges to create a database.

.Parameter dbServer

(Required) The path to the SQL server, which hosts the eRecruiter database. 
Usually the path looks like SERVERNAME\INSTANCENAME.

.Parameter dbName

(Required) The name of the database to access.

.Parameter dbUserName

(Required) The database user, who has access to the database provided in parameter "dbName".

.Parameter dbUserPassword

(Required) The password of the database user.

.Parameter scriptDirectory

(Required) The directory which contains the SQL scripts "CreateEmptySchema.sql"" and "CreateEmptyData.sql".
The scripts are found in "er-install-package.zip" file.
If no directory is provided an error is presented.

.Notes

Version: 1.0

#>

param(
    [parameter(mandatory=$true)] [string] $dbServer #SERVERNAME\INSTANCENAME
    ,[parameter(mandatory=$true)] [string] $dbName #eRecruiter_DB_Name
    ,[parameter(mandatory=$true)] [string] $dbUserName #eRecruiter_DB_User 
    ,[parameter(mandatory=$true)] [string] $dbUserPassword #eRecruiter_DB_User_Password
    ,[parameter(mandatory=$true)] [string] $scriptDirectory #SQL script schema and 
    )


# No spaces or other special characters please
$databaseServer = "SERVERNAME\INSTANCENAME" #SERVERNAME\INSTANCENAME
$databaseName = "eRecruiter_DB_Name"

$databaseUserName = "eRecruiter_DB_User"
$databaseUserPassword = "eRecruiter_DB_User_Password"

#path to sql scripts (included in er-install-package.zip)
$sqlScriptForSchema = Join-Path $scriptDirectory "\CreateEmptySchema.sql"   # CreateEmptySchema.sql
$sqlScriptForEmptyData = Join-Path $scriptDirectory "\CreateEmptyData.sql"  # CreateEmptyData.sql

###########################################
function WriteWarning
{
    param($warningText)

    Write-Warning $warningText
    echo $_.Exception|format-list -force
}

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$server = new-Object ('Microsoft.SqlServer.Management.Smo.Server') "$databaseServer"

#Default connection is via Windows integrated, need to tell Powershell we do NOT want that
$server.ConnectionContext.LoginSecure=$false; 

$server.ConnectionContext.set_Login("$databaseUserName"); 
$server.ConnectionContext.set_Password("$databaseUserPassword") 


# Step (1) -- Validating user credentials
#########################################
try{
    Write-Host "Validating user credentials ..."
    $server.databases | Select Name  | Out-Null
    Write-Host "`tOK"  -ForegroundColor green
}
catch {
    WriteWarning "`nCould not connect to sql server - verify credentials`n"
    exit -1
}


# Step (2) -- Check if database exists
######################################
Write-Host "`nCheck if database $databaseName exists ..."
$dbObject = $server.Databases[$databaseName] #create SMO handle to database

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
    Invoke-SqlCmd -InputFile $sqlScriptForSchema -ServerInstance $server -Database $databaseName        
    Write-Host "`tComplete"  -ForegroundColor green

    Write-Host "`nAdd initial data to database ..."
    Invoke-SqlCmd -InputFile $sqlScriptForEmptyData -ServerInstance $server -Database $databaseName        
    Write-Host "`tComplete"  -ForegroundColor green
}
catch [Exception]
{
    WriteWarning "Sql script for creating schema and/or add empty data failed!"   
}


# Step (4) -- Assign user to schema owner
#########################################
try
{
    $schemas = @("db_owner","ecBase","OrderManagement")
    foreach($schema in $schemas)
    {
        Write-Host "`nSet owner for schema '$schema' ..."
        $dbSchema = $dbObject.Schemas[$schema]
        $dbSchema.Owner = $databaseUserName
        $dbSchema.Alter()
        Write-Host("`tUser $databaseUserName successfully own schema $dbSchema.") -ForegroundColor green
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
        $dbCatalog.Owner = $databaseUserName
        $dbCatalog.Alter()
        Write-Host("`tUser $databaseUserName successfully own catalog $dbCatalog.") -ForegroundColor green
    }
}
catch [Exception]
{
    WriteWarning "`nAssign user as catalog owner failed!"   
    exit -5
}

Write-Host "`n`n!!! Script prepare db for eRecruiter application finished !!!`n`n" -ForegroundColor green
