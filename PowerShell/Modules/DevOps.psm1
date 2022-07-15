$DevOps = @{
    Headers      = $null
    PrefixURL    = "https://vsrm.dev.azure.com"
    Organization = $null
    Project      = $null
    APIVersion   = "?api-version=6.0"
    PostfixURL   = "_apis/release/definitions"
    UserToken    = $null
    Proxy        = $null
}

New-Variable -Name DevOps -Value $DevOps -Scope Script -Force

function DevOps.Initialize
{
    param
    (
        [Parameter(HelpMessage='Owner/Organization')]
        [ValidateNotNull()]
        [string]$org,
        [Parameter(HelpMessage='Project')]
        [ValidateNotNull()]
        [string]$project,
        [Parameter(HelpMessage='User Token for DevOps')]
        [ValidateNotNull()]
        [string]$userToken
    )

    $DevOps.Organization = $org
    $DevOps.Project      = $project
    $DevOps.UserToken    = $userToken
    $DevOps.Proxy        = ([System.Net.WebRequest]::GetSystemWebproxy()).GetProxy($DevOps.PrefixURL)

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

    $user = whoami
    $accessToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$userToken)))

    $DevOps.Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $DevOps.Headers.Add("Authorization", "Basic $($accessToken)")
}

function DevOps.DefinitionList
{
    param
    (
        [Parameter(HelpMessage='Include deleted definitions?')]
        [switch]$isIncludeDeleted
    )
    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    $definitionsUrl = "$($DevOps.PrefixURL)/$($DevOps.Organization)/$($DevOps.Project)/$($DevOps.PostfixURL)$($DevOps.APIVersion)"

    try
    {
        $definitionRequest = Invoke-RestMethod $definitionsUrl -Method 'GET' -Headers $DevOps.Headers -Proxy $DevOps.Proxy -ProxyUseDefaultCredentials -UseDefaultCredentials

        if($isIncludeDeleted.IsPresent)
        {
            $result.Data = $definitionRequest.value
        }
        else
        {
            $result.Data = $definitionRequest.value | Where-Object {$_.isDeleted -eq 0}
        }

        $result.IsOk = $true
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}

function DevOps.DefinitionGet
{
    param
    (
        [Parameter(HelpMessage='Definition ID')]
        [ValidateNotNull()]
        [string]$definitionID,
        [Parameter(HelpMessage='AppCenter store only')]
        [switch]$isAppCenterOnly,
        [Parameter(HelpMessage='Active tasks only')]
        [switch]$isActiveOnly
    )

    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    $definitionUrl = "$($DevOps.PrefixURL)/$($DevOps.Organization)/$($DevOps.Project)/$($DevOps.PostfixURL)/$($definitionID)/$($DevOps.APIVersion)"

    try
    {
        $definitionRequest = Invoke-RestMethod $definitionUrl -Method 'GET' -Headers $DevOps.Headers -Proxy $DevOps.Proxy -ProxyUseDefaultCredentials

        if($isAppCenterOnly.IsPresent)
        {
            $result.Data = $definitionRequest | Where-Object {$_.environments.deployPhases.workflowTasks.inputs.destinationType -eq "store"}
        }
        else
        {
            $result.Data = $definitionRequest
        }
        if($isActiveOnly.IsPresent)
        {
            $result.Data = $result.Data | Where-Object {$_.environments.deployPhases.workflowTasks.Enabled -eq $true}
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

function DevOps.DefinitionUpdate
{
    param
    (
        [Parameter(HelpMessage='Payload')]
        [ValidateNotNull()]
        $payload
    )

    $result = @{
        IsOk    = $false
        Message = ""
    }

    $definitionUrl = "$($DevOps.PrefixURL)/$($DevOps.Organization)/$($DevOps.Project)/$($DevOps.PostfixURL)$($DevOps.APIVersion)"

    try
    {
        $updateRequest  = Invoke-RestMethod $definitionUrl -Method 'PUT' -Headers $DevOps.Headers -Body $payload -ContentType "application/json" -Proxy $DevOps.Proxy -ProxyUseDefaultCredentials
        $result.IsOk    = $true
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}

function DevOps.TokenList
{
    param
    (
        [Parameter(HelpMessage='Access token')]
        [ValidateNotNull()]
        $accessToken
    )

    $headers = @{
        'Authorization' = "Bearer $($accessToken)"
    }

    $result = @{
        Data    = $null
        IsOk    = $false
        Message = ""
    }

    $url = "https://vssps.dev.azure.com/$($DevOps.Organization)/_apis/tokens/pats?api-version=6.1-preview.1"

    try
    {
        $tokenRequest   = Invoke-RestMethod $url -Method 'GET' -Headers $headers -Proxy $DevOps.Proxy -ProxyUseDefaultCredentials
        $result.Data    = $tokenRequest
        $result.IsOk    = $true
        $result.Message = "Success"
    }
    catch
    {
        $result.Message = $_.ErrorDetails
    }

    return $result
}

function DevOps.TokenDelete
{
    param
    (
        [Parameter(HelpMessage='Access Token')]
        [ValidateNotNull()]
        [string]$accessToken,
        [Parameter(HelpMessage='PAT Token Name')]
        [ValidateNotNull()]
        [string]$tokenName
    )
    $result = @{
        IsOk    = $false
        Message = ""
    }

    $headers = @{
        'Authorization' = "Bearer $($accessToken)"
    }

    try
    {
        $tokenResult = DevOps.TokenList -accessToken $accessToken

        foreach($tr in $tokenResult.Data.patTokens)
        {
            if($tr.displayName -eq $tokenName)
            {
                $url            = "https://vssps.dev.azure.com/$($DevOps.Organization)/_apis/tokens/pats?authorizationId=$($tr.authorizationId)&api-version=7.1-preview.1"
                $deleteRequest  = Invoke-RestMethod $url -Method 'DELETE' -Headers $headers -Proxy $DevOps.Proxy -ProxyUseDefaultCredentials

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