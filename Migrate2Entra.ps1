$DBServer = "avmsrv002"
$Database = "BETATEST_PROD_DEMO"

$Override = $false #See line 128 when enabled

[string]$LogPath = "C:\_au2mator\BAK"
[string]$LogfileName = "Migration2Entra.log"


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
    $Connection.ConnectionString = "server='$servername';database='$database';trusted_connection=false; integrated security='true'"
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
    @{TableName = "Requests"; Columns = @("TargetUserId", "InitiatedBy", "ApprovedBy", "CreatedBy") },
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

#Override Array Example Seidlm = michael.seidl@au2mator.com
# This is used when the samaccountname cannot be found in AD, so you can change to a UPN directly
$Override = @(
    @{OldSamAccountName = "au2mator.loc\seidlm"; NewUPN = "michael.seidl@au2mator.com" }
    @{OldSamAccountName = "au2mator.local\seidlm"; NewUPN = "michael.seidl@au2mator.com" }
)

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