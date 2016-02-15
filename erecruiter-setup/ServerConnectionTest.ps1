# copied from https://github.com/eRecruiter/eRecruiter.PowerShell
#
# Create an empty database and user with access to this database for the eRecruiter application
# 
# Requirements:
#      - Sql "super" user (to add the database and user)

cls

$databaseServer = "WIN-ILGQ5E73KCJ\WIN2016SQL" #SERVERNAME\INSTANCENAME
$databaseName = "eRecruiter"
$databaseSuperUser = "SqlSuperUser"
$databaseSuperUserPassword = "4epunktSQL"

# with these credentials the new user will be created
$databaseUserLoginName = "eRecruiterSqlUser"
$databaseUserName = "eRecruiterSqlUser"
$databaseUserPassword = "4epunktSQL"

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

$server.ConnectionContext.set_Login("$databaseSuperUser"); 
$server.ConnectionContext.set_Password("$databaseSuperUserPassword") 


# Step (1) -- Validating user credentials
#########################################
try{
    Write-Host "Validating user credentials ..."
    $server.databases | Select Name  | Out-Null
    Write-Host "`tOK"  -ForegroundColor green
}
catch {
    WriteWarning "`n(1) Could not connect to database - verify credentials`n"
    exit -1
}



#$cs = "Server=$databaseServer;Database=$databaseName;User Id=$databaseUserName;Password=$databaseUserPassword;"

function Test-SQLConnection{
    param([parameter(mandatory=$true)][string[]] $Instances)

    $return = @()
    foreach($InstanceName in $Instances){
        $row = New-Object –TypeName PSObject –Prop @{'InstanceName'=$InstanceName;'StartupTime'=$null}
        try{
            $check=Invoke-Sqlcmd -ServerInstance $InstanceName -Database eRecruiter -Query "SELECT @@SERVERNAME as Name,Create_Date FROM sys.databases WHERE name = 'TempDB'" -ErrorAction Stop -ConnectionTimeout 3
            $row.InstanceName = $check.Name
            $row.StartupTime = $check.Create_Date
        }
        catch{
            #do nothing on the catch
        }
        finally{
            $return += $row
        }
    }
    return $return
}

Test-SQLConnection -Instances $databaseServer