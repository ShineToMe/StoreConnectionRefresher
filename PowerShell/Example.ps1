#region Variables

# Secret of "Visual Studio App Center - INTUNE" in Azure Enterprise applications
# You can obtain it by executing following commands in PowerShell:
# PS> Connect-AzureAD
# PS> New-AzureADServicePrincipalPasswordCredential -ObjectId "ObjectID from 'Visual Studio App Center - INTUNE'"
# Do not store it in plain text! This is just sample PowerShell
# Better to store it in Azure Key Vault and get it via "Get-AzKeyVaultSecret" from "Az PowerShell" module
# https://docs.microsoft.com/en-us/powershell/azure/?view=azps-8.1.0&viewFallbackFrom=azps-7.2.0
$secret = ""

# ApplicationID of "Visual Studio App Center - INTUNE" in Azure Enterprise applications
$clientID = ""

# Tenant ID of your AD organization
$tenantID = ""

# Static value
$redirectUri = "https://appcenter.ms/auth/intune/callback"

# Your own User API token for AppCenter.
# More details:
# https://docs.microsoft.com/en-us/appcenter/api-docs/#creating-an-app-center-user-api-token
$AppCenterToken = ""

# Your AppCenter Organization/Owner
# https://appcenter.ms/orgs/$thisIsIt$
$Organization = ""

# Your AppCenter Application
# https://appcenter.ms/orgs/$yourOrganization$/apps/$thisIsIt$
$Application = ""
#endregion

#region Modules import
try
{
    if((Get-Module -Name "OAuth").Name -ne $null)
    {
        Remove-Module AppCenter
    }
    if((Get-Module -Name "AppCenter").Name -ne $null)
    {
        Remove-Module AppCenter
    }
}
catch
{}
finally
{
    Import-Module ./Modules/OAuth2.psm1
    Import-Module ./Modules/AppCenter.psm1
}
#endregion

#region obtaining tokens
OAuth.Initialize -clientID $clientID -clientSecret $secret -tenantID $tenantID -redirectURI $redirectUri

# Do not forget to set "ClientID" option to the same value as here inside exe.config
$authCode= .\AuthCode\IEBased\AppCenterAuthenticatorIE.exe

$token = OAuth.TokenGet -authCode $authCode
#endregion

#region AppCenter actions
if($token.IsOk)
{
    AppCenter.Initialize -org $Organization -token $AppCenterToken -tenantID $tenantID -refreshToken $token.Data.refresh_token

    $oldStore = AppCenter.StoreConnectionGet -appName $Application

    $storeDelete = AppCenter.StoreConnectionDelete -name $oldStore.Data.name -appName $Application

    $newStore = AppCenter.StoreConnectionCreate -appName $Application -name $oldStore.Data.name -category $oldStore.Data.intune_details.app_category.name -audience $oldStore.Data.intune_details.target_audience.name

    Write-Host "Old ConnectionID: $($oldStore.Data.id)"
    Write-Host "New ConnectionID: $($newStore.Data.id)"
}
#endregion