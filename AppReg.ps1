#Settings
$AppRegName = "au2matorAppv2"
$AppRegNotes = "Created by au2mator for au2mator 5.1 Entra ID Integration"
$SecretDurationInYears = 1



#check if module is installed Az
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -AllowClobber -Force -Scope CurrentUser
}

#Import Module
Import-Module Az.Accounts


#Connect to Azure to get Token
Connect-AzAccount
$AZAccessToken = Get-AzAccessToken -ResourceTypeName MSGraph
$token = $AZAccessToken.Token
$tokenCredential = [PSCredential]::new("token", $token)
$authHeader = @{ 
    Authorization = "Bearer $($tokenCredential.GetNetworkCredential().Password)"  
}





#New App Registration
$NewApp_body = @{
    displayName    = $AppRegName
    signInAudience = "AzureADMyOrg"
    notes          = $AppRegNotes
    optionalClaims = @{
        accessToken = @(
            @{
                additionalProperties = @(
                    "include_externally_authenticated_upn"
                )
                essential            = "false"
                name                 = "upn"
                source               = $null
            }
        )
        idToken     = @()
        saml2Token  = @()
    }
} | ConvertTo-Json -Depth 10

$NewApp_app = Invoke-RestMethod -method POST  -Uri "https://graph.microsoft.com/v1.0/applications" -Headers $authHeader -Body $NewApp_body -ContentType "application/json"

#$App
$AppId = $NewApp_app.appId
$AppObjectId = $NewApp_app.id


#Update API with Expose API
$PermissionId = [Guid]::NewGuid().Guid
$ExposeAPI_body = @{
    IDENTIFIERURIS = @("api://$AppId")
    api            = @{
        requestedAccessTokenVersion = 2
        oauth2PermissionScopes      = @(
            @{
                adminConsentDescription = "Allow the application to access au2matorApp on behalf of the signed-in user."
                adminConsentDisplayName = "Access au2matorApp"
                id                      = $PermissionId
                isEnabled               = $true
                type                    = "User"
                userConsentDescription  = "Allow the application to access au2matorApp on your behalf."
                userConsentDisplayName  = "Access au2matorApp"
                value                   = "Access"
            }
        )
    }
} | ConvertTo-Json -Depth 10
$ExposeAPI_App = Invoke-RestMethod -method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$AppObjectId" -Headers $authHeader -Body $ExposeAPI_body -ContentType "application/json"



#Configure API Permissions
$Permission_body = @{
    requiredResourceAccess = @(
        @{
            resourceAppId  = "00000003-0000-0000-c000-000000000000"
            resourceAccess = @(
                @{
                    id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
                    type = "Role"
                },
                @{
                    id   = "14dad69e-099b-42c9-810b-d002981feec1"
                    type = "Scope"
                },
                @{
                    id   = "5b567255-7703-4780-807c-7be8301ae99b"
                    type = "Role"
                },
                @{
                    id   = "df021288-bdef-4463-88db-98f22de89214"
                    type = "Role"
                }
            )
        },
        @{
            resourceAppId  = "$AppId"
            resourceAccess = @(
                @{
                    id   = $PermissionId 
                    type = "Scope"
                }
            )
        }
    )
} | ConvertTo-Json -Depth 10
$Permission_App = Invoke-RestMethod -method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$AppObjectId" -Headers $authHeader -Body $Permission_body -ContentType "application/json"




#New Client Secret
$Secret_body = @{
    passwordCredential = @{
        displayName = "au2matorAppSecret-$(Get-Date -Format 'yyyyMMdd')"
        endDateTime = (Get-Date).AddYears($SecretDurationInYears)
    }
} | ConvertTo-Json -Depth 10
$Secret_App = Invoke-RestMethod -method POST  -Uri "https://graph.microsoft.com/v1.0/applications/$AppObjectId/addPassword" -Headers $authHeader -Body $Secret_body -ContentType "application/json"

$SecretValue = $Secret_App.secretText




#Logo

#save file to a temp location
$tempPath = [System.IO.Path]::GetTempPath()
$logoPath = [System.IO.Path]::Combine($tempPath, "AppReg.png")
$logo | Set-Content -Path $logoPath -Encoding utf8
$logo = $logoPath   
Invoke-RestMethod -Uri "https://au2mator.com/my-content/AppReg.png" -OutFile $logo


$Logo_App = Invoke-RestMethod -method PUT  -Uri "https://graph.microsoft.com/v1.0/applications/$AppObjectId/logo" -Headers $authHeader -InFile  $logo -ContentType "image/png"





#ServicePrincipal
$ServicePrincipal_body = @{
    appId = $AppId
} | ConvertTo-Json -Depth 10
$ServicePrincipal_app = Invoke-RestMethod -method POST  -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" -Headers $authHeader -Body $ServicePrincipal_body -ContentType "application/json"






#Return for Setup
Write-Output "-------------------"

Write-Output "ClientID: $AppId"
Write-Output "Secret: $SecretValue"
Write-Output "TenantId: $($AZAccessToken.TenantId)"

Write-Output "-------------------"


Write-Output "Continue with Step 7 of the au2mator Entra ID Integration Guide here: https://support.au2mator.com/support/solutions/articles/103000372530-how-to-create-app-reg-for-entra-id-integration"


