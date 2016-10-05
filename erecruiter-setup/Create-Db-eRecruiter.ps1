<#

.Synopsis

# Script available at https://github.com/eRecruiter/eRecruiter.Powershell

Create an empty database and an user with access to this database for the eRecruiter application.

.Description

Requirements:
    - Sql server
    - Sql "super" user (to create the database and add a user)
    - user with database access (default language "German", password never expires)   

The user must have database access with the priviliges to create a database.


.Parameter dbServer

(Optional) The path to the SQL server, which hosts the eRecruiter database. 
Usually the path looks like SERVERNAME\INSTANCENAME.
If none is provided, localhost is used.

.Parameter dbName

(Required) The name of the database to access.

.Parameter dbSuperUserName

(Optional) The database super user, who has access to the database server provided in parameter "dbName" 
and has priviliges to create the database and users.
If none is provided the current user who executes this script is used and the connection to the SQL server is made with windows authentication.
If a value is provided the connection switches to mixed-mode authentication.

.Parameter dbSuperUserPassword

(Optional) The password of the database super user provided in parameter "dbSuperUserName".
If no value for parameter "dbSuperUserName" is provided, this parameter is ignored.

# with these credentials the new user will be created
.Parameter dbUserLoginName

(Optional) The database user, who has access to the server, has priviliges to create the database and users.

.Parameter dbUserName

(Optional) The database user, who should access to the database server provided in parameter "dbName".
If none or no "dbUserPassword" is provided the current user who executes this script is used.

.Parameter dbUserPassword

(Optional) The password of the database user.

.Notes

Version: 1.0

#>

param(
    [string] $dbServer = "localhost" #SERVERNAME\INSTANCENAME
    ,[parameter(mandatory=$true)] [string] $dbName #eRecruiter_DB_Name
    ,[string] $dbSuperUserName #eRecruiter_DB_User 
    ,[string] $dbSuperUserPassword #eRecruiter_DB_User_Password
    ,[string] $dbUserLoginName #the login name of the user to be created
    ,[string] $dbUserName #the user name of the user to be created
    ,[string] $dbUserPassword #the password of the user to be created
    )

$databaseServer = $dbServer
$databaseName = $dbName
$databaseSuperUser = $dbSuperUserName
$databaseSuperUserPassword = $dbSuperUserPassword

###########################################
function WriteWarning( $warningText ) {
    Write-Warning $warningText
    echo $_.Exception|format-list -force
}

# Connect to sql server
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$server = new-Object ('Microsoft.SqlServer.Management.Smo.Server') "$databaseServer"

#If super user credentials are provided, check if they are valid and sign the user in
if ([string]::IsNullOrEmpty($dbSuperUserName)) {   
    Write-Host "Using windows integrated connection to connect sql server."
}
else {
    Write-Host "Using mixed-mode connection with provided credentials 'super user: $databaseSuperUserName' to connect sql server."
    #Default connection is via Windows integrated, need to tell Powershell we do NOT want that
    $server.ConnectionContext.LoginSecure=$false; 

    $server.ConnectionContext.set_Login("$databaseSuperUser"); 
    $server.ConnectionContext.set_Password("$databaseSuperUserPassword") 
}

#If database user credentials are provided, check if they are valid and sign the user in
if ([string]::IsNullOrEmpty($dbUserLoginName) -or [string]::IsNullOrEmpty($dbUserName)) {   
    Write-Host "Using windows integrated connection to connect sql server."
    $currentUser = $(whoami)
    Write-Host "Current user is " $currentUser
    $databaseUserLoginName = $databaseUserName = $currentUser
    $databaseUserPassword = "TODO GET password"
}
else {
    $databaseUserLoginName = $dbUserLoginName
    $databaseUserName = $dbUserName
    $databaseUserPassword = $dbUserPassword
}

# Step (1) -- Validating user credentials
#########################################
try{
    Write-Host "Validating user credentials ..."
    $server.databases | Select Name  | Out-Null
    Write-Host "`tOK"  -ForegroundColor green
}
catch {
    WriteWarning "`n(1) Could not connect to sql server - verify credentials`n"
    exit -1
}


# Step (2) -- Check if database exists
######################################
$dbObject = $server.Databases[$databaseName] #create SMO handle to database

if ($dbObject)
{
    $title = "`nDatabase $databaseName already exists!"
    $message = "Do you want to delete the existing database?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Deletes the existing database."

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Exit the script and leave database untouched"

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 1) 

    switch ($result){
        0 {
            # Yes selected
            #instead of drop we will use KillDatabase
            #KillDatabase drops all active connections before dropping the database.
            $server.KillDatabase($databaseName)
          }
        1 {
            # No selected
            Write-Host "`nScript exited - database is untouched`n" -ForegroundColor green
            exit
          }
    }
}

# Step (3) -- Create database
#############################
try{
    Write-Host "`nCreate database for eRecruiter application ..."
    $db = New-Object Microsoft.SqlServer.Management.Smo.Database($server, "$databaseName")
    $db.Create()
    Write-Host "`tDatabase created successfully on: " (Get-Date) -ForegroundColor green
}
catch {
    WriteWarning "`t(3) Could not create database - verify user permissions`n"
    exit -3
}


# Step (4) -- Add user to sql-server login
##########################################
try
{
    Write-Host "`nCreate login for sql server ..."
    # drop login if it exists
    if ($server.Logins.Contains($databaseUserLoginName))  
    {   
        $server.KillAllprocesses($databaseName)
        Write-Host("`tDeleting the existing login $databaseUserLoginName.")
        $server.Logins[$databaseUserLoginName].Drop() 
    }

    $login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $server, $databaseUserLoginName
    $login.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::SqlLogin
    $login.PasswordExpirationEnabled = $false
    $login.Create($databaseUserPassword)
    Write-Host("`tLogin $databaseUserLoginName created successfully.") -ForegroundColor green

}
catch [Exception]
{
    WriteWarning "(4) Creating login for sql server failed!"   
    exit -4
}


# Step (5) -- Create user for database access
#############################################
try
{
    Write-Host "`nCreate user for database access ..."
    $dbObject = $server.Databases[$DatabaseName]

    # drop user if it exists
    if ($dbObject.Users[$databaseUserName])
    {
        Write-Host("Dropping user $databaseUserName on $dbObject.")
        $dbObject.Users[$databaseUserName].Drop()
    }

    $dbUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.User -ArgumentList $dbObject, $databaseUserName
    $dbUser.Login = $databaseUserName
    $dbUser.Create()
    Write-Host("`tUser $dbUser created successfully.") -ForegroundColor green
}
catch [Exception]
{
    WriteWarning "(5) Creating user for database access failed!"   
    exit -5
}


# Step (6) -- Assign database role to user
##########################################
try
{
    $roleName = "db_owner"

    Write-Host "`nAssign database role '$roleName' to user ..."
    $dbrole = $dbObject.Roles[$roleName]
    $dbrole.AddMember($databaseUserName)
    $dbrole.Alter()
    Write-Host("`tUser $dbUser successfully added to $roleName role.") -ForegroundColor green
}
catch [Exception]
{
    WriteWarning "Assign database role '$roleName' to user failed!"   
    exit -6
}

Write-Host "`n`n!!! Script finished !!!`n`n" -ForegroundColor green
