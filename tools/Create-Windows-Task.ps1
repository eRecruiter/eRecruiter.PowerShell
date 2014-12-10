function Create-Windows-Task-That-Runs-Every-15-Minutes {
    param($name, $program, $programArguments, $username, $password)
    
    $service = New-Object -ComObject "Schedule.Service"
    $service.Connect($ENV:ComputerName)

    $rootFolder = $service.GetFolder("\")
    $taskDefinition = $service.NewTask(0)
      
    $trigger = $taskDefinition.Triggers.Create(2)
    $trigger.StartBoundary = (Get-Date 00:00AM).AddDays(1) | Get-Date -Format yyyy-MM-ddTHH:ss:ms
    $trigger.DaysInterval = 1
    $repetition = $trigger.Repetition
    $repetition.Duration = "P1D"
    $repetition.Interval = "PT15M"
   
    $action = $taskDefinition.Actions.Create(0)
    $action.Path = $program
    $action.Arguments = $programArguments
    
    $principal = $taskDefinition.Principal
    $principal.RunLevel = 0 # 0=normal, 1=Highest Privileges
       
    $rootFolder.RegisterTaskDefinition($name, $taskDefinition, 6, $username, $password, 1)
}



function Create-Windows-Task-That-Runs-Every-Midnight {
    param($name, $program, $programArguments, $username, $password)
    
    $service = New-Object -ComObject "Schedule.Service"
    $service.Connect($ENV:ComputerName)

    $rootFolder = $service.GetFolder("\")
    $taskDefinition = $service.NewTask(0)
      
    $trigger = $taskDefinition.Triggers.Create(2)
    $trigger.StartBoundary = (Get-Date 00:00AM).AddDays(1) | Get-Date -Format yyyy-MM-ddTHH:ss:ms
    $trigger.DaysInterval = 1
   
    $action = $taskDefinition.Actions.Create(0)
    $action.Path = $program
    $action.Arguments = $programArguments
    
    $principal = $taskDefinition.Principal
    $principal.RunLevel = 0 # 0=normal, 1=Highest Privileges
       
    $rootFolder.RegisterTaskDefinition($name, $taskDefinition, 6, $username, $password, 1)
}



# based on script written by Ingo Karstein, https://gallery.technet.microsoft.com/PowerShell-script-to-add-b005e0f6
function Grant-Logon-As-Batch-Job ($user) {
    $policy = "SeBatchLogonRight"

    $sidstr = $null
    try {
	    $ntprincipal = new-object System.Security.Principal.NTAccount "$user"
	    $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	    $sidstr = $sid.Value.ToString()
    } catch {
	    $sidstr = $null
    }

    if ([string]::IsNullOrEmpty($sidstr)) {
	    Write-Host "Account not found."
	    exit -1
    }


    $tmp = [System.IO.Path]::GetTempFileName()
    secedit.exe /export /cfg "$($tmp)" 

    $c = Get-Content -Path $tmp 
    $currentSetting = ""

    foreach ($s in $c) {
	    if( $s -like "$policy*") {
		    $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		    $currentSetting = $x[1].Trim()
	    }
    }

    if ($currentSetting -notlike "*$($sidstr)*") {

	    if ([string]::IsNullOrEmpty($currentSetting)) {
		    $currentSetting = "*$($sidstr)"
	    } else {
		    $currentSetting = "*$($sidstr),$($currentSetting)"
	    }

	
	$outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
$policy = $($currentSetting)
"@
	    $tmp2 = [System.IO.Path]::GetTempFileName()

	    $outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force

	    Push-Location (Split-Path $tmp2)
	
	    try {
		    secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS | Out-Null
	    } finally {	
		    Pop-Location
	    }
    } else {
	    
    }
}