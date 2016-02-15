# copied from https://github.com/eRecruiter/eRecruiter.PowerShell
#
# Prepare a given database for the eRecruiter application
# 
# Requirements:
#      - database
#      - user with database access (default langugae "German", password never expire)    


# No spaces or other special characters please
$databaseServer = "SERVERNAME\INSTANCENAME" #SERVERNAME\INSTANCENAME
$databaseName = "eRecruiter_DB_Name"

$databaseUserName = "eRecruiter_DB_User"
$databaseUserPassword = "eRecruiter_DB_User_Password"

#path to sql scripts (included in er-install-package.zip)
$sqlScriptForSchema = "C:\ENTER_PATH_HERE\CreateEmptySchema.sql"   # CreateEmptySchema.sql
$sqlScriptForEmptyData = "C:\ENTER_PATH_HERE\CreateEmptyData.sql"  # CreateEmptyData.sql

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
    WriteWarning "`nAssign user as schmea owner failed!"   
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