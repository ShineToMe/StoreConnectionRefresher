# Welcome to OAuth2 Magic!

$OAData = [ordered]@{
    ClientID     = $null
    ClientSecret = $null
    TenantID     = $null
    RedirectURI  = $null
    AuthURL      = $null
    TokenData    = $null
}

New-Variable -Name OAData -Value $OAData -Scope Script -Force

function OAuth.Initialize
{
    param
    (
        [Parameter(HelpMessage='Client ID')]
        [ValidateNotNull()]
        [string]$clientID,
        [Parameter(HelpMessage='Client Secret')]
        [ValidateNotNull()]
        [string]$clientSecret,
        [Parameter(HelpMessage='Tenant ID')]
        [ValidateNotNull()]
        [string]$tenantID,
        [Parameter(HelpMessage='Redirect URI')]
        [ValidateNotNull()]
        [string]$redirectURI,
        [Parameter(HelpMessage='Authentication URL')]
        [ValidateNotNull()]
        [string]$authURL
    )

    $OAData.ClientID     = $clientID
    $OAData.ClientSecret = $clientSecret
    $OAData.TenantID     = $tenantID
    $OAData.RedirectURI  = $redirectURI
    $OAData.AuthURL      = $authURL
}

function OAuth.TokenGet
{
    param (
    [Parameter(HelpMessage='Authorization Code from AppCenter')]
        [ValidateNotNull()]
        [string]$authCode
    )

    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    $tokenBody = @{
        grant_type    = "authorization_code"
        client_id     = $OAData.ClientID
        client_secret = $OAData.ClientSecret
        scope         = "offline_access openid profile email"
        code          = $authCode
        redirect_uri  = $OAData.RedirectURI
    }

    $tokenUrl = "https://login.microsoftonline.com/$($OAData.TenantID)/oauth2/v2.0/token"

    try
    {
        $tokenResult      = Invoke-RestMethod $tokenUrl -Method 'POST' -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
        $result.Data      = $tokenResult
        $result.IsOk      = $true
        $result.Message   = "Success"
        $OAData.TokenData = $tokenResult
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}