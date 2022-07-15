# Welcome to AppCenter Magic!

$AppCenter = [ordered]@{
    PrefixURL         = "https://api.appcenter.ms/v0.1"
    Organization      = $null
    Headers           = $null
    UserLevelAPIToken = $null
    RefreshToken      = $null
    TenantID          = $null
    User              = $null
    Proxy             = $null
}

New-Variable -Name AppCenter -Value $AppCenter -Scope Script -Force

function AppCenter.UserGet
{
    $userUrl = "$($AppCenter.PrefixURL)/user"
    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    try
    {
        $userResult     = Invoke-RestMethod $userUrl -Method 'GET' -Headers $AppCenter.Headers -Proxy $AppCenter.Proxy -ProxyUseDefaultCredentials
        $result.IsOk    = $true
        $result.Data    = $userResult
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}

function AppCenter.Initialize
{
    param
    (
        [Parameter(HelpMessage='Owner/Organization')]
        [ValidateNotNull()]
        [string]$org,
        [Parameter(HelpMessage='User-level token')]
        [ValidateNotNull()]
        [string]$token,
        [Parameter(HelpMessage='Tenant ID')]
        [ValidateNotNull()]
        [string]$tenantID,
        [Parameter(HelpMessage='OAuth2 Refresh token')]
        [string]$refreshToken
    )
    
    $AppCenter.Organization      = $org
    $AppCenter.Application       = $appName
    $AppCenter.UserLevelAPIToken = $token
    $AppCenter.TenantID          = $tenantID

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

    $AppCenter.Proxy = ([System.Net.WebRequest]::GetSystemWebproxy()).GetProxy($AppCenter.PrefixURL)
    $AppCenter.User  = (AppCenter.UserGet).Data

    $AppCenter.Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $AppCenter.Headers.Add("X-API-Token", $AppCenter.UserLevelAPIToken)

    if($refreshToken -ne $null)
    {
        $AppCenter.RefreshToken = $refreshToken
    }
}

function AppCenter.StoreConnectionGet
{
    param
    (
        [Parameter(HelpMessage='Application')]
        [ValidateNotNull()]
        [string]$appName
    )

    $storeUrl = "$($AppCenter.PrefixURL)/apps/$($AppCenter.Organization)/$($appName)/distribution_stores"
    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    try
    {
        $store          = Invoke-RestMethod $storeUrl -Method 'GET' -Headers $AppCenter.Headers -ContentType "application/json" -Proxy $AppCenter.Proxy -ProxyUseDefaultCredentials
        $result.IsOk    = $true
        $result.Data    = $store
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}

function AppCenter.StoreConnectionDelete
{
    param
    (
        [Parameter(HelpMessage='Application')]
        [ValidateNotNull()]
        [string]$appName,
        [Parameter(HelpMessage='Store-Connection name')]
        [ValidateNotNull()]
        [string]$name
    )

    $deleteUrl = "$($AppCenter.PrefixURL)/apps/$($AppCenter.Organization)/$($appName)/distribution_stores/$($name)"
    $result = @{
        IsOk    = $false
        Message = ""
    }

    try
    {
        $deleteResult   = Invoke-RestMethod $deleteUrl -Method 'DELETE' -Headers $AppCenter.Headers -Proxy $AppCenter.Proxy -ProxyUseDefaultCredentials
        $result.IsOk    = $true
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}

function AppCenter.StoreConnectionCreate
{
    param
    (
        [Parameter(HelpMessage='Application')]
        [ValidateNotNull()]
        [string]$appName,
        [Parameter(HelpMessage='Store-Connection name')]
        [ValidateNotNull()]
        [string]$name,
        [Parameter(HelpMessage='Application category name')]
        [ValidateNotNull()]
        [string]$category,
        [Parameter(HelpMessage='Target audience name (AD-Group)')]
        [ValidateNotNull()]
        [string]$audience
    )

    $storeUrl = "$($AppCenter.PrefixURL)/apps/$($AppCenter.Organization)/$($appName)/distribution_stores"

    $newStoreObject = [ordered]@{
        type = "intune"
        name = $name
        track = "production"
        intune_details =
        [ordered]@{
            secret_json =
            [ordered]@{ refresh_token = "$($AppCenter.RefreshToken)" }
            target_audience = @{ name = "$($audience)" }
            app_category = @{ name = "$($category)" }
            tenant_id = "$($AppCenter.TenantID)"
        }
        created_by = "$((AppCenter.UserGet).Data.id)"
        created_by_principal_type = "user"
    }

    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    try
    {
        $newStoreJson   = $newStoreObject | ConvertTo-Json
        $newStoreResult = Invoke-RestMethod $storeUrl -Method 'POST' -Headers $AppCenter.Headers -Body $newStoreJson -ContentType "application/json" -Proxy $AppCenter.Proxy -ProxyUseDefaultCredentials
        $result.Data    = $newStoreResult
        $result.IsOk    = $true
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }
    
    return $result
}

function AppCenter.StoreConnectionRefresh
{
    param
    (
        [Parameter(HelpMessage='Application')]
        [ValidateNotNull()]
        [string]$appName
    )

    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    try
    {
        $store = AppCenter.StoreConnectionGet -appName $appName
        $deleteStore = AppCenter.StoreConnectionDelete -appName $appName -name $store.Data.name
        $newStore = AppCenter.StoreConnectionCreate -name $store.Data.name -category $store.Data.intune_details.app_category.name -audience $store.Data.intune_details.target_audience.name -appName $appName

        $result.Data = @{
            OldStore = $store
            NewStore = $newStore
        }
        $result.IsOk    = $true
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}

function AppCenter.TokenList
{
    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    $url = "https://appcenter.ms/api/v0.1/api_tokens"

    try
    {
        $response = Invoke-RestMethod $url -Method 'GET' -Headers $AppCenter.Headers -Proxy $AppCenter.Proxy -ProxyUseDefaultCredentials

        $result.Data    = $response
        $result.IsOk    = $true
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}

function AppCenter.TokenDelete
{
    param
    (
        [Parameter(HelpMessage='Token description')]
        [ValidateNotNull()]
        [string]$tokenName
    )

    $result = @{
        IsOk    = $false
        Message = "Not found"
    }

    try
    {
        $tokenResult = AppCenter.TokenList

        foreach($tr in $tokenResult.Data)
        {
            if($tr.description -eq $tokenName)
            {
                $url = "$($AppCenter.PrefixURL)/api_tokens/$($tr.id)"
        
                Invoke-RestMethod $url -Method 'DELETE' -Headers $AppCenter.Headers -Proxy $AppCenter.Proxy -ProxyUseDefaultCredentials

                $result.IsOk    = $true
                $result.Message = "Success"
            }
        }
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}