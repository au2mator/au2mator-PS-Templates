<#
This Script helps you to change all User Relations in your au2mator DB from samaccountname to UPN, which is necessary for the migration to Entra ID.
SamAccount was used for local AD as USer Reference, but for Entra ID we need to change this to UPN
We also change your au2mator Admin Group reference in the Settings table to the ObjectID of the Entra ID Group, where your au2mator Admins are in, and also update the security groups used for Service and Service Groups to use the ObjectID instead of the samaccountname.

Make sure to make a backup of your database before running this script, and test it in a non-production environment first, to make sure it works as expected with your specific setup and customizations.

Some More Details for Entra ID: https://support.au2mator.com/a/solutions/articles/103000370564


#>





$DBServer = "10.18.13.11" #au2mator SQL DEB Server
$Database = "au2mator" #au2mator DB Name
$au2matorDBUser = "au2mator-dbuser" #au2mator DB User
$au2matorDBPW = "PASSWORD" #au2mator DB Password

$EntraAdminGroupObjectID = "5458b5c2-1eec-4631-bd99-d49086401b12" #ObjectID of the Entra ID Group where the au2mator Admins are in





#Security Group Mapping for Service and Service Groups
#The OldGroupSam is the value from table ServiceAdGroupLinks and ServiceGroupAdGroupLinks, colummn GroupoSid, which is currently the samaccountname of the group. The new value will be the ObjectID of the Entra ID Group, which is stored in the column GroupSid after migration. The GroupName column will also be updated to match the new group name in Entra ID.
$SecurityMapping = @(
    @{OldGroupSam = "contoso.local\Group1"; NewGroupObject = "7faa38a2-205c-4ec7-a979-24ba2871eb63"; NewGroupName = "New Group 1" }
    @{OldGroupSam = "contoso.local\Group2"; NewGroupObject = "5458b5c2-1eec-4631-bd99-d49086401b12"; NewGroupName = "New Group 2" }
)







$Override = $false #See line 128 when enabled

[string]$LogPath = "C:\_au2mator\_SourceControl\au2mator\Test" 
[string]$LogfileName = "Migration2Entra.log"


#No Changes from here on necessary for the migration, unless you want to add an override for specific users that cannot be found in AD by their samaccountname, see line 128 for example
function Write-au2matorLog {
    [CmdletBinding()]
    param
    (
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Type,
        [string]$Text
    )

    # Set logging path
    if (!(Test-Path -Path $logPath)) {
        try {
            $null = New-Item -Path $logPath -ItemType Directory
            Write-Verbose ("Path: ""{0}"" was created." -f $logPath)
        }
        catch {
            Write-Verbose ("Path: ""{0}"" couldn't be created." -f $logPath)
        }
    }
    else {
        Write-Verbose ("Path: ""{0}"" already exists." -f $logPath)
    }
    [string]$logFile = '{0}\{1}_{2}.log' -f $logPath, $(Get-Date -Format 'yyyyMMdd'), $LogfileName
    $logEntry = '{0}: <{1}> <{2}> <{3}> {4}' -f $(Get-Date -Format dd.MM.yyyy-HH:mm:ss), $Type, $RequestId, $Service, $Text
    Add-Content -Path $logFile -Value $logEntry
}

function ConnectToDB {
    # define parameters
    param(
        [string]
        $servername,
        [string]
        $database
    )
    # create connection and save it as global variable
    $global:Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server='$servername';database='$database';trusted_connection=false;User Id=$au2matorDBUser;Password=$au2matorDBPW"
    $Connection.Open()
}

function ExecuteSqlQuery {
    # define parameters
    param(

        [string]
        $sqlquery

    )
    #Begin {
    If (!$Connection) {
    }
    elseif ($Connection.State -eq 'Closed') {
        try {
            # if connection was closed (by an error in the previous script) then try reopen it for this query
            $Connection.Open()
        }
        catch {
            Remove-Variable -Scope Global -Name Connection
        }
    }
    #}

    #Process {
    #$Command = New-Object System.Data.SQLClient.SQLCommand
    $command = $Connection.CreateCommand()
    $command.CommandText = $sqlquery

    try {
        $result = $command.ExecuteReader()
    }
    catch {
        $Connection.Close()
    }
    $Datatable = New-Object "System.Data.Datatable"
    $Datatable.Load($result)

    return $Datatable

    #}

    #End {
    #}
}

Write-au2matorLog -Type "INFO" -Text "Starting Migration to Entra ID Script"
ConnectToDB -servername $DBServer -database $Database


#Array of tables and columns to migrate
$TablesToMigrate = @(
    @{TableName = "Requests"; Columns = @("TargetUserId", "InitiatedBy", "ApprovedBy", "CreatedBy", "ModifiedBy") },
    @{TableName = "Actors"; Columns = @("CreatedBy", "ModifiedBy", "UserID") },
    @{TableName = "Announcements"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "ApiKeys"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "AzureCredentials"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "FavoriteServices"; Columns = @("CreatedBy", "ModifiedBy", "UserID") },
    @{TableName = "RequestActors"; Columns = @("CreatedBy", "ModifiedBy", "UserID") },
    @{TableName = "RequestParameters"; Columns = @("CreatedBy") },
    @{TableName = "RunbookParameterMappings"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "SCOServerInstances"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "ServiceAdGroupLinks"; Columns = @("CreatedBy") },
    @{TableName = "ServiceGroupAdGroupLinks"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "ServiceGroupImages"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "ServiceGroups"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "ServiceHistories"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "ServiceImages"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "Services"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "Settings"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "SystemDataSources"; Columns = @("CreatedBy", "ModifiedBy") },
    @{TableName = "UserLanguages"; Columns = @("CreatedBy", "ModifiedBy", "UserID") },
    @{TableName = "UserLoginDetails"; Columns = @("CreatedBy", "ModifiedBy", "UserID") },
    @{TableName = "WelcomeMessages"; Columns = @("CreatedBy", "ModifiedBy") }
)


#Array to migrate Security Groups, which are stored as SIDs in the database, and need to be replaced with the ObjectID of the Entra ID Group. The GroupName will also be updated to match the new group name in Entra ID.
$SecurityTablesToMigrate = @(
    @{TableName = "ServiceGroupAdGroupLinks"; Columns = @("GroupSid", "GroupName") },
    @{TableName = "ServiceAdGroupLinks"; Columns = @("GroupSid", "GroupName") }
)

#Override Array Example Seidlm = michael.seidl@au2mator.com
# This is used when the samaccountname cannot be found in AD, so you can change to a UPN directly
$Override = @(
    @{OldSamAccountName = "au2mator.local\Seidlm"; NewUPN = "michael.seidl@au2mator.com" }
    
)

#Set Admin Group
$AdminupdateQuery = @"
                update Settings
                set [Label] = '$EntraAdminGroupObjectID'
                where [Type] = '35'
"@
Write-au2matorLog -Type "INFO" -Text "Executing update query: $AdminupdateQuery to set Entra Admin Group ObjectID: $EntraAdminGroupObjectID in Settings table"
ExecuteSqlQuery -sqlquery $AdminupdateQuery
Write-au2matorLog -Type "INFO" -Text "Updated Entra Admin Group ObjectID to: $EntraAdminGroupObjectID in Settings table"



foreach ($table in $TablesToMigrate) {
    Write-au2matorLog -Type "INFO" -Text "Processing table: $($table.TableName)"
    Write-Host "Processing table: $($table.TableName)"
    $tableName = $table.TableName
    foreach ($column in $table.Columns) {
        Write-au2matorLog -Type "INFO" -Text "Processing column: $column in table: $tableName"
        $selectQuery = @"
        select DISTINCT [$column] from [$tableName] where [$column] is not null and [$column] not like '%@%' and [$column] <> ''

"@
        Write-au2matorLog -Type "INFO" -Text "Executing query: $selectQuery"
        $results = ExecuteSqlQuery -sqlquery $selectQuery

        #check forerach and get aduser from AD and replace wirth UPN
        foreach ($row in $results) {
            Write-au2matorLog -Type "INFO" -Text "Processing user ID: $($row.$column)"
            $userId = $row.$column

            # Get user from AD
            $adUser = $null
            try {
                $adUser = Get-ADUser -Identity $userId.split("\")[1] -Properties UserPrincipalName
                Write-au2matorLog -Type "INFO" -Text "Found AD user for ID: $userId"
            }
            catch {
                
                if ($Override) {
                    #Check for override
                    try {
                        $overrideEntry = $Override | Where-Object { $_.OldSamAccountName -eq $userId }
                        if ($overrideEntry) {
                            #set $adUser.$adUser to overridden UPN
                            $adUser = @{}   
                            $adUser.UserPrincipalName = $overrideEntry.NewUPN
                            Write-au2matorLog -Type "INFO" -Text "Found AD user for overridden ID: $userId"
                        }
                    }
                    catch {
                        Write-au2matorLog -Type "ERROR" -Text "Error retrieving AD with override user for ID: $userId. $_"
                    }
                }
                else {
                    Write-au2matorLog -Type "INFO" -Text "No override found for user ID: $userId"
                }

                Write-au2matorLog -Type "ERROR" -Text "Error retrieving AD user for ID: $userId. $_"
            }

            if ($adUser) {
                $upn = $adUser.UserPrincipalName
                Write-au2matorLog -Type "INFO" -Text "Retrieved UPN: $upn for user ID: $userId"

                # Update the database with UPN
                $updateQuery = @"
                update [$tableName]
                set [$column] = '$upn'
                where [$column] = '$userId'
"@
                Write-au2matorLog -Type "INFO" -Text "Executing update query: $updateQuery"
                ExecuteSqlQuery -sqlquery $updateQuery
                Write-au2matorLog -Type "INFO" -Text "Updated user ID: $userId to UPN: $upn in table: $tableName, column: $column"
            }
            else {
                Write-au2matorLog -Type "WARNING" -Text "User not found in AD for ID: $userId"
            }
        }
    }   
}


foreach ($Table in $SecurityTablesToMigrate) {
    Write-au2matorLog -Type "INFO" -Text "Processing security group mapping for table: $($Table.TableName)"
    Write-Host "Processing security group mapping for table: $($Table.TableName)"
    $tableName = $Table.TableName
    foreach ($column in $Table.Columns) {
        Write-au2matorLog -Type "INFO" -Text "Processing column: $column in table: $tableName"
        $selectQuery = @"
        select DISTINCT [$column] from [$tableName] where [$column] is not null and [$column] <> ''
"@
        Write-au2matorLog -Type "INFO" -Text "Executing query: $selectQuery"
        $results = ExecuteSqlQuery -sqlquery $selectQuery   

        foreach ($row in $results) {
            Write-au2matorLog -Type "INFO" -Text "Processing security group: $($row.$column)"
            $groupSid = $row.$column

            # Get mapping for security group
            $mapping = $SecurityMapping | Where-Object { $_.OldGroupSam -eq $groupSid }
            if ($mapping) {
                $newGroupObjectId = $mapping.NewGroupObject
                $newGroupName = $mapping.NewGroupName
                Write-au2matorLog -Type "INFO" -Text "Found mapping for security group: $groupSid. New Object ID: $newGroupObjectId, New Group Name: $newGroupName"

                # Update the database with new Object ID and Group Name
                if ($column -eq "GroupSid") {
                    $updateQuery = @"
                    update [$tableName]
                    set [$column] = '$newGroupObjectId'
                    where [$column] = '$groupSid'
"@
                    Write-au2matorLog -Type "INFO" -Text "Executing update query: $updateQuery"
                    ExecuteSqlQuery -sqlquery $updateQuery
                    Write-au2matorLog -Type "INFO" -Text "Updated security group: $groupSid to new Object ID: $newGroupObjectId in table: $tableName, column: $column"
                }
                elseif ($column -eq "GroupName") {
                    $updateQuery = @"
                    update [$tableName]
                    set [$column] = '$newGroupName'
                    where [$column] = '$groupSid'
"@
                    Write-au2matorLog -Type "INFO" -Text "Executing update query: $updateQuery"
                    ExecuteSqlQuery -sqlquery $updateQuery
                    Write-au2matorLog -Type "INFO" -Text "Updated security group: $groupSid to new Group Name: $newGroupName in table: $tableName, column: $column"
                }
            }
            else {
                Write-au2matorLog -Type "WARNING" -Text "No mapping found for security group: $groupSid"
            }
        }
    }
}   