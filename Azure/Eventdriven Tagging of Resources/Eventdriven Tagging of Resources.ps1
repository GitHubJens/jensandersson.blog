# Created by Jens Andersson (Blog: https://jensandersson.blog) - Feel free to use the script but please don't remove this line.
# This script adds madatory tags to all resources and resourcegroups (If you deploy something in the resource group).

# Pre requisites:
# First you need to create an autoamtion account and a Run As Account for this Autoamtion Account. The Run As Account need to 
# be contributor on all the subscription that it will be adding tags to resources on.

# Setup Guide:
# Azure Portal -> Azure Monitor -> Alerts -> Select Subscription -> New Alert Rule -> Select Target (Select Subscription and Done) -> Alert Criteria, Add Criteria ->
# Input:Activity Log, Event Category:Administrative, Resource Type:All, Resource group:All, Resource:All, Operation name:Create Deployment (deployments), Level:All ->
# Action: Action group (Create Action Group that activates this Runbook.

# How to test this when finished setting up:
# Create a Resource Group and a resource inside it.
# You can navigate to the runbook and check the status of it. It will run on several events until it finds the correct one.
# When it is finished it will have added the tags to the resource and its resource group if it not already have tags for the values.

# Other information:
# If the resource(es) are crated by an AAD Application you will get the object ID as the owner and createdBy tag. I would recommend that you
# add an extra job to the deployment that adds the tags to the resource so that you are able to get the real owner and createdBy

param
(
    [Parameter (Mandatory=$false)]
    [object]$webhookData # This is the log that is sent to the webhook from the alarm
)

$ErrorActionPreference = "stop" # Always full stop on error since this can create large problems!

# Function for updating the tags of the object
function AddAllTagsToResource($deploymentId, $correlationId, $createdByTag, $creationtimeTag, $ownerTag)
{
    # Checks if the resource is a deployment. It should be. Then checks if it is finished otherwise we wait for it to finish
    # so that we can tag all the resources in the deployment since otherwise we won't be able to catch that the other resources
    # were created just recently since they won't have statusCode = Created
    if($resourceId -like "*deployments*")
    {
        $deployment = Get-AzureRmResourceGroupDeployment -Name $deploymentId.Split("/")[$deploymentId.Split("/").count - 1] -ResourceGroupName $deploymentId.Split("/")[4] | Select-Object -Property *
        while($deployment.ProvisioningState -ne "Succeeded")
        {
            Write-Output "Waiting for the resource deployment to finish. (Status Now: $($deployment.ProvisioningState)) - Waiting 10 seconds!"
            Sleep -Seconds 10
            $deployment = Get-AzureRmResourceGroupDeployment -Name $deploymentId.Split("/")[$deploymentId.Split("/").count - 1] -ResourceGroupName $deploymentId.Split("/")[4] | Select-Object -Property *
        }
    }

    # This variable is used to fill up with all correlating objects in the deployment. We need to do this since there is only one "statusCode=Created" response for each deployment.
    # This makes a lot of sense if you think of each deployment involving several resources as one large ARM-template. So in order to cope with this fact we will be iterating through
    # the whole deployment and find all resources that were a part of the deployment and set tags for them all.
    $resourceObjects = @()
    $resourceIds = (Get-AzureRmLog -CorrelationId $correlationId).ResourceId | Select-Object -Unique
    foreach($resourceId in $resourceIds)
    {
        # Removing the deployment resources since we dont want to tag them
        if($resourceId -notlike "*deployments*")
        {
            # If the resource ID splitted up by the character / is more than 5 it is a normal resource, otherwise it is a resource group
            if($resourceId.Split("/").count -gt 5)
            {
                $resourceObjects += Get-AzureRmResource | Where-Object { $_.ResourceId -eq $resourceId }
            }
            else
            {
                $resourceObjects += Get-AzureRmResourceGroup | Where-Object { $_.ResourceId -eq $resourceId }
            }
        }
    }
    # Get rid of duplicates that you can get from resources that have typoes in ther resourceId. Like App Service Plans can be named Microsoft.Web/serverfarms and Microsoft.Web/serverFarms in different logs
   $resourceObjects += Get-AzureRmResourceGroup | Where-Object { $_.ResourceGroupName -eq $deployment.ResourceGroupName }
    $resourceObjects = $resourceObjects | Select -Property * -Unique

    # Checking if the caller (creator) has a id with a @ in it. This tells us if it was created by a user 
    # or by a process like Azure DevOps. If it was created by Azure DevOps it will not be able to add the 
    # correct owner or createdBy. Since it isn't possible to add tags to resource groups in Azure DevOps 
    # (VSTS) right as you create them this also makes it hard to use these to find out who the creator is.
    if($createdByTag -notlike "*@*")
    {
        Write-Output "The caller id is: $($createdByTag) which tells us it is created by a process or application.`nYou can find out which application with the following PowerShell code: Get-AzureADObjectByObjectId -ObjectIds <GUID>"
    }

    foreach($resource in $resourceObjects)
    {
        $resourceGroupNameTag = $($resource.ResourceId).Split("/")[4]
        $companyTag = $($resourceGroupNameTag.Substring(0,3))
        $environmentTag = $($resourceGroupNameTag.Substring(3,1))

        # Handle resources created automatically by a kubernetes cluster deployment
        # (Example resource group name: MC_jenpjens002rg_jenpjens001kcl_westeurope gives us companyCode jen and environment p)
        if($resourceGroupNameTag -like "MC_*")
        {
            $companyTag = $resourceGroupNameTag.Substring(3,3)
            $environmentTag = $resourceGroupNameTag.Substring(6,1)
        }

        if(($resource.ResourceId).Split("/").count -eq 5)
        {
            # Resource group
            $displaynameTag = ($resource.ResourceId).Split("/")[4]
        }
        else
        {
            # Normal Resource
            $displaynameTag = ($resource.ResourceId).Split("/")[$(($resource.ResourceId).Split("/").count - 1)]
        }

        # Output all the tags that will be added for logging purposes
        Write-Output "Attempting to add tag to resource with Resource ID: $($resource.ResourceId)"
        Write-Output "companyTag: $companyTag"
        Write-Output "environmentTag: $environmentTag"
        Write-Output "resourcegroupTag: $resourceGroupNameTag"
        Write-Output "displaynameTag: $displaynameTag"
        Write-Output "createdBy: $createdByTag"
        Write-Output "creationtime: $creationtimeTag"
        Write-Output "owner: $ownerTag"
        Write-Output " "

        # if the resource don't have any tags since before create the first tag.
        # else if the resource have tags since before add the tag to the list and keep the old ones.
        if($resource.Tags.Count -eq 0)
        {
            Write-Output "No tags present on the resource - Adding all tags!"
            Set-AzureRmResource -Tag @{company = $companyTag; 
                                       environment = $environmentTag; 
                                       resourcegroup = $resourceGroupNameTag; 
                                       displayname = $displaynameTag; 
                                       createdBy = $createdByTag; 
                                       creationtime = $creationtimeTag; 
                                       owner = $ownerTag } -ResourceId $resource.ResourceId -Force -ErrorAction SilentlyContinue
        }
        else
        {
            # Get all tags from the object
            $tags = $resource.tags

            # Check if the object contains the tag, otherwise add it
            Write-Output "Skipping some tags since there are already some on the resource!"
            if(!$tags.ContainsKey("company")){ Write-Output "Adding company=$companyTag"; $tags += @{company=$companyTag} }
            if(!$tags.ContainsKey("environment")){ Write-Output "Adding environment=$environmentTag"; $tags += @{environment=$environmentTag} }
            if(!$tags.ContainsKey("resourcegroup")){ Write-Output "Adding resourceGroupName=$resourceGroupNameTag"; $tags += @{resourcegroup=$resourceGroupNameTag} }
            if(!$tags.ContainsKey("displayname")){ Write-Output "Adding displayname=$displaynameTag"; $tags += @{displayname=$displaynameTag} }
            if(!$tags.ContainsKey("createdBy")){ Write-Output "Adding createdBy=$createdByTag"; $tags += @{createdBy=$createdByTag} }
            if(!$tags.ContainsKey("creationtime")){ Write-Output "Adding creationtime=$creationtimeTag"; $tags += @{creationtime=$creationtimeTag} }
            if(!$tags.ContainsKey("owner")){ Write-Output "Adding owner=$ownerTag"; $tags += @{owner=$ownerTag} }
        
            # Finally update the tags of the resource
            Set-AzureRmResource -Tag $tags -ResourceId $resource.ResourceId -Force -ErrorAction SilentlyContinue
        }
        
        Write-Output " "
    }
}

if($webhookData)
{
    $webhookBody = ConvertFrom-Json -InputObject $webhookData.RequestBody
    if($webhookBody.schemaId -eq "Microsoft.Insights/activityLogs")
    {
        $alertContext = [object](($webhookBody.data).context).activityLog
        if(($webhookBody.data).status -eq "Activated")
        {
            $resourceType = $alertContext.resourceType
            $resourceName = (($alertContext.resourceId).Split("/"))[-1]
            $resourceGroupName = $alertContext.resourceGroupName
            $SubId = $alertContext.subscriptionId
            $resourceId = $alertContext.resourceId
            $caller = $alertContext.caller
            $eventTimesstamp = $alertContext.eventTimestamp
            $statusCode = $alertContext.properties.statusCode
            $status = $alertContext.status # Not as reliable as statusCode
            $subStatus = $alertContext.subStatus # Not as reliable as statusCode
            $httpRequest = $alertContext.httpRequest
            $restMethod = (ConvertFrom-Json $($alertContext.httpRequest -replace [regex]::Escape("\"),"")).method
            $propertiesResponseBodyTags = (ConvertFrom-Json $($alertContext.properties.responseBody -replace [regex]::Escape("\"),"")).tags
            $subscriptionId = $alertContext.subscriptionId
            $correlationId = $alertContext.correlationId

            Write-Output "-----------------------------------------------------------"
            Write-Output "EVENT LOG"
            Write-Output "-----------------------------------------------------------"
            Write-Output "resourceType: $resourceType"
            Write-Output "resourceName: $resourceName"
            Write-Output "resourceGroupName: $resourceGroupName"
            Write-Output "subscriptionId: $SubId"
            Write-Output "resourceId: $resourceId"
            Write-Output "caller: $caller"
            Write-Output "eventTimestamp: $eventTimesstamp"
            Write-Output "statusCode: $statusCode"
            Write-Output "status: $status"
            Write-Output "subStatus: $subStatus"
            Write-Output "httpRequest: $httpRequest"
            Write-Output "restMethod: $restMethod"
            Write-Output "propertiesResponseBodyTags: $propertiesResponseBodyTags"
            Write-Output "subscriptionId: $subscriptionId"
            Write-Output "correlationId: $correlationId"
            Write-Output "-----------------------------------------------------------"

            # Login into Azure Resource Manager - Remember that you need to create an automation account connection before running this code.
            $automationConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'
            Login-AzureRmAccount -ServicePrincipal -Tenant $automationConnection.TenantID -ApplicationId $automationConnection.ApplicationID `
                                 -CertificateThumbprint $automationConnection.CertificateThumbprint | Out-Null

            # Change the subscription context to the one that created the event
            $subscription = $(Get-AzureRmSubscription -SubscriptionId $subscriptionId)
            Write-Output "Logging in to subscription `"$($subscription.Name)`" since the event was generated on that subscription."
            Set-AzureRmContext -Subscription $subscription.Name

            # Changing the caller from the application to a user if this is a kubernetes cluster resource group that were created by the backend services:
            if($resourceGroupName -like "MC_*")
            {
                # Get all the logs from the main resource group where the user created the kubernetes cluster
                $logs = Get-AzureRmLog -ResourceGroupName $($resourceGroupName.Split("_")[1])

                # Get the first caller that has a @ in the name. This means it will pick: "gregor.andersson@email.no" instead of the application GUID: "392bcf33-51b9-33ea-afdc-86d5eb5182e1"
                $caller = $logs.caller | Where { $_ -like "*@*" } | Select -First 1
            }
            
            # Get the tags that we need from the log:
            $createdByTag = $caller
            $creationtimeTag = $eventTimesstamp
            $ownerTag = $caller

            # This is the code that will be running if the Resource was successfully created
            if((($statusCode -eq "Created") -or ($subStatus -eq "Created")) -and ($restMethod -in @("PUT", "POST")))
            {
                Write-Output "Resource `"$resourceName`" successfully passed the validation."
                AddAllTagsToResource -deploymentId $resourceId -correlationId $correlationId -createdByTag $createdByTag -creationtimeTag $creationtimeTag -ownerTag $ownerTag
            }
            else
            {
                Write-Output "The JSON content did not fulfill any criterias for processing so no action was taken."
            }
        }
        else
        {
            Write-Output "No action taken since the status was not `"Activated`". Alert status was: $(($webhookBody.data).status)"
        }
    }
    else
    {
        Write-Output "Webhook schema is not `"Microsoft.Insights/activityLogs`" and therefore the event will be ignored. Schema type was `"$($webhookBody.schemaId)`""
    }
}
else
{
    Write-Error "Failed to start runbook: This runbook is meant to be started from an Azure alert webhook only."
} 
