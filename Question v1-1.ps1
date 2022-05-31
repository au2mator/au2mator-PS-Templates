#########
# au2mator PS Services
# Type: PowerShell Question
#
# Title: PS Template
#
# v 1.0 Initial Release
# 
#
# Init Release: 31.05.2022
# Last Update: 31.05.2022
# Code Template V 1.1
#
# URL: https://au2mator.com/documentation/configure-powershell-question-type/?utm_source=github&utm_medium=social&utm_campaign=PS_Template&utm_content=PS1
# Github: https://github.com/au2mator/au2mator-PS-Templates
#
# PreReq: au2mator 4.5 or higher required
#
#################


#region  InputParamaters
param ($au2matorhook)
$jsondata = $au2matorhook | ConvertFrom-Json

#$Var=$jsondata.var

#endregion  InputParamaters

#region Variables

#Environment
[string]$CredentialStorePath = "C:\_SCOworkingDir\TFS\PS-Services\CredentialStore" #see for details: https://au2mator.com/documentation/powershell-credentials/?utm_source=github&utm_medium=social&utm_campaign=PS_Template&utm_content=PS1

[string]$LogPath = "C:\_SCOworkingDir\TFS\PS-Services\AZURE - Create Azure Resource Group"
[string]$LogfileName = "Question-GetResourceRoles"


#endregion Variables



#region CustomVariables

#
#
#
#


#endregion CustomVariables





#region Functions
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

#endregion Functions



#region CustomFunctions

#
#
#
#


#endregion CustomFunctions


#region Script
Write-au2matorLog -Type INFO -Text "Start Script"

try {
    Write-au2matorLog -Type INFO -Text "Try1"
    
    
    try {
        Write-au2matorLog -Type INFO -Text "Try2"

        $Return=""
        
    }
    catch {
        Write-au2matorLog -Type ERROR -Text "Error to Try2"
        Write-au2matorLog -Type ERROR -Text $Error
    
        $au2matorReturn = "Error to Try2, Error: $Error"
        $TeamsReturn = "Error to Try2" #No Special Characters allowed
        $AdditionalHTML = "Error to Try2
        <br>
        Error: $Error
            "
        $Status = "ERROR"
    }
}
catch {
    Write-au2matorLog -Type ERROR -Text "Error to Try1"
    Write-au2matorLog -Type ERROR -Text $Error

    $au2matorReturn = "Error to Try1, Error: $Error"
    $TeamsReturn = "Error to Try1" #No Special Characters allowed
    $AdditionalHTML = "Error to Try1
    <br>
    Error: $Error
        "
    $Status = "ERROR"
}


#endregion Script


return $Return
