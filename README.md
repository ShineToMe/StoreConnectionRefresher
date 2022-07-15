# Introduction
This repository contains PowerShell modules, that will help you with automation of refreshing Store Connections between MS AppCenter and MS Intune.  

# PowerShell Modules (PowerShell/Modules)
## OAuth2.psm1
Required to get authentication token from AzureAD in order to simulate AppCenter WebUI behavior.  
  
## AppCenter.psm1
Provides abstraction layer for some of AppCenter Open API.  
Required for getting, deleting and creating store connections.  
Check [OpenAPI](https://openapi.appcenter.ms/) for more details.  
Ignore "/v0.1/apps/{owner_name}/{app_name}/distribution_stores" - example for Intune is incorrect.

## DevOps.psm1
Provide abstraction layer for some of DevOps API.  
Required for getting and updating release definitions.  
Check [DevOps API](https://docs.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-7.1) for more details.  

# AuthCode Executables (PowerShell/AuthCode)
The only purpose is to emulate call of browser to AppCenter WebUI and intercept authorization code, that we will use in OAuth2.psm1.  
Two different implementations: IE based and Edge based.  
Binaries from [AppCenterAuthenticator Solution](https://github.com/ShineToMe/StoreConnectionRefresher/tree/main/AppCenterAuthenticator).  

## Prerequisites
You need to set ClientID in .exe.configuration of the binary.  
To get your ClientID, go to Enterprise Apps in Azure and search for "Visual Studio App Center - INTUNE".  
ClientID equals Application ID of this enterprise app.  
More details [here](https://docs.microsoft.com/en-us/appcenter/distribution/stores/intune).

## Compatibility
By default it's easier to use IE-based version.  
To check, if it's working in your environment, open PowerShell, navigate to folder, containing AppCenterAuthenticatorIE.exe and run it.  
You may be asked for MFA confirmation.  
If the outcome of the app is OAuth code, than you can use this lightweight version.  

## Edge based version (PowerShell/AuthCode/EdgeBased)
This version requires more configuration:  
You need to have MS Edge SDK installed or placed to the same folder, if you want to use fixed version.  
To use fixed version, set "BrowserPath" in "AppCenterAuthenticator.exe.config" file to path of fixed version.  
More details in [MS Docs](https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution).  

# Example (PowerShell/Example.ps1)
Simple PowerShell script, that shows, how using modules above you can refresh your AppCenter-Intune store connection.  
Please, be aware, that after that you will have new DestinationID of the store (because we delete old store connection and create new with same parameters).  

## DevOps hints
You can automatically update destination store IDs in DevOps release definitions, by using DevOps.psm1 functions combined with approach from Example.ps1.  
This will automatically get all tasks for publishing to AppCenter Intune Store and updates destination store IDs inside, without need of manually passing AppCenter Organization and Applications.  
```powershell
DevOps.Initialize -userToken $DevOpsToken -org $DevOpsOrganization -project $DevOpsProject
$releases = DevOps.DefinitionList
foreach ($def in $releases.Data)
{
    $release = DevOps.DefinitionGet -definitionID $def.id
    $releaseJson = ""
    
    if($release.Data -ne $null)
    {
        foreach($env in $release.Data.environments)
        {
            foreach ($phase in $env.deployPhases)
            {
                foreach ($workflowTask in $phase.workflowTasks)
                {
                    foreach ($input in $workflowTask.inputs)
                    {
                        if(($input.appSlug -ne $null) -and ($workflowTask.enabled -eq $true) -and ($input.destinationType -eq "store"))
                        {
                            $appCenterOrg = $input.appSlug.Split('/')[0]
                            $appCenterApp = $input.appSlug.Split('/')[1]
                            
                            AppCenter.Initialize -org $appCenterOrg -token $AppCenterToken -tenantID $tenantID -refreshToken $token.refresh_token
                            
                            $oldStore = AppCenter.StoreConnectionGet -appName $appCenterApp
                            $storeDelete = AppCenter.StoreConnectionDelete -name $oldStore.Data.name -appName $appCenterApp
                            $newStore = AppCenter.StoreConnectionCreate -appName $appCenterApp -name $oldStore.Data.name -category $oldStore.Data.intune_details.app_category.name -audience $oldStore.Data.intune_details.target_audience.name
                            
                            $updateMessage = "Updated AppCenter store connection:`r`nOld id: $($oldStore.Data.id)`r`nNew id: $($newStore.Data.id)"
                            
                            if($release.Data.comment -eq $null)
                            {
                                Add-Member -InputObject $release.Data -NotePropertyName comment -NotePropertyValue $updateMessage
                            }
                            else
                            {
                                $release.Data.comment = $release.Data.comment + ";`r`n" + $updateMessage
                            }
                            
                            $input.destinationStoreId = $newStore.Data.id
                            $releaseJson = $release.Data | ConvertTo-Json -Depth 20
                        }
                    }
                }
            }
        }
    }
    
    if ($releaseJson -ne "")
    {
        $updateRequest = DevOps.DefinitionUpdate -payload $releaseJson
        if($updateRequest.IsOk)
        {
            Write-Host "Release id: $($release.Data.id):`r`n$($release.Data.comment)"
        }
        else
        {
            Write-Host "Update of release #$($release.Data.id) failed!"
        }
        Write-Host
    }
}
```
