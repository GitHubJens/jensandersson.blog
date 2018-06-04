# Created by Jens Andersson - https://jensandersson.blog/

# 1. Creates a new Resource Group is there isn't one already
# 2. Creates a new Automation Account
# 3. Creates a new AAD Application
# 4. Creates a Key Vault to store the Certificate that will be used by the AAD Application (Run As Account)
# 5. Sets access rights to the Key Vault (Only what is needed, Create Certificate and Get Secret)
# 6. Create Certificate in the Key Vault
# 7. Create a certificate in your temp folder using the values from the Certificate in the Key Vault
# 8. Create the AAD Application public key using the Certificate
# 9. Creates a Service Principal for the AAD Application 
# 10. Gives the Run As Account (The AAD Application) contributor access to the Subscription
# 11. Upload the Certificate to the Automation Account
# 12. Create a new Automation Connection for the Automation Account
# 13. Create the RunBook

# Parameters that you need to change:
$subscription = "Which subscription do you want to create the solution in?"
$resourceGroupName = "What do you want to name the Resource Group?"
$automationAccountName = "What do you want to name the Automation Account?"
$keyVaultName = "What do you want to name the Key Vault?"
$location = "West Europe"
$selfsignedCertificatePlainPassword = "What password do you want to use for the self signed certificate?"
$certificateLifetimeInMonths = 12 # Months until you need to update the certificate for the Run As Account
$aadApplicationName = $automationAccountName + "aadapp" # The name of the AAD Application that the Run As Account will be using

# No need to change these variables:
$pfxCertificatePath = "$env:Temp\$automationAccountName`AzureRunAsCertificate.pfx"

# Make sure the script is ran as an Administrator, otherwise this fails when creating certificates:
if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    Write-Error "You need to start the script as an administrator!"
    PAUSE
}

Login-AzureRmAccount -Subscription $subscription

# Create resource group if it doesn't exist already
if([string]::IsNullOrEmpty((Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)))
{
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
}

# Create the automation account if it doesn't exist already
if([string]::IsNullOrEmpty((Get-AzureRmAutomationAccount -Name $automationAccountName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)))
{
    New-AzureRmAutomationAccount -Name $automationAccountName -ResourceGroupName $resourceGroupName -Location $location -Plan "Basic"
}

# Create an Azure AD application, AD App Credential, AD ServicePrincipal:
$aadApplication = New-AzureRmADApplication -DisplayName $aadApplicationName -HomePage "http://$aadApplicationName" `
                                           -IdentifierUris "http://$((New-Guid).Guid)"

# Create new Key Vault to store the Certificate in
New-AzureRmKeyVault -Name $keyVaultName -Location $location -ResourceGroupName $resourceGroupName

# Get the object ID of your user and give yourself access to create new certificates in it
$yourUserObjectId = (Get-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName).AccessPolicies[0].ObjectId
Set-AzureRmKeyVaultAccessPolicy -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -ObjectId $yourUserObjectId `
                                -PermissionsToCertificates "create" -PermissionsToSecrets "get"

# Create a new certificate policy with a 1 year valid self signed certificate
$certificatePolicy = New-AzureKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" `
                                                        -SubjectName $("CN=" + $automationAccountName + "AzureRunAsCertificate") `
                                                        -IssuerName "Self" -ValidityInMonths 12 -ReuseKeyOnRenewal

# Add the certificate to the Key Vault
$addCertificate = Add-AzureKeyVaultCertificate -VaultName $keyVaultName -Name $($automationAccountName + "AzureRunAsCertificate") `
                                               -CertificatePolicy $certificatePolicy

do
{
    Write-Output "Waiting 15 seconds for certificate to get status `"completed`". Status is now: `"$($addCertificate.Status)`"."
    sleep -Seconds 15
    $certificateStatus = (Get-AzureKeyVaultCertificateOperation -VaultName $keyVaultName -Name $($automationAccountName + "AzureRunAsCertificate")).Status
}
until($certificateStatus -eq "completed")
Write-Output "Finished creating the certificate: $($automationAccountName + "AzureRunAsCertificate")"

# Get certificate secret in bytes, create a collection and import the certificate to it:
$certificateSecret = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $($automationAccountName + "AzureRunAsCertificate")).SecretValueText
$pfxCertificateByteString = [System.Convert]::FromBase64String($certificateSecret)
$certificateCollection = New-Object "System.Security.Cryptography.X509Certificates.X509Certificate2Collection"
$certificateCollection.Import($pfxCertificateByteString, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
   
# Export the certificate from the collection by getting the encrypted string and writing it to the temp folder
$encryptedCertificateByteString = $certificateCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $selfsignedCertificatePlainPassword)
[System.IO.File]::WriteAllBytes($pfxCertificatePath, $encryptedCertificateByteString)

# Get certificate information and value needed for uploading the certificate to the AAD Application
$pfxCertificateObject = New-Object -TypeName "System.Security.Cryptography.X509Certificates.X509Certificate2" -ArgumentList @($pfxCertificatePath, $selfsignedCertificatePlainPassword)
$pfxCertificateValue = [System.Convert]::ToBase64String($pfxCertificateObject.GetRawCertData())

# Add the certificate to the AAD Application
New-AzureRmADAppCredential -ApplicationId $aadApplication.ApplicationId.Guid -CertValue $pfxCertificateValue `
                           -StartDate $pfxCertificateObject.NotBefore -EndDate $pfxCertificateObject.NotAfter

# Create Service Principal for the Run As Account:
New-AzureRmADServicePrincipal -ApplicationId $aadApplication.ApplicationId

# Sleeping a minute since creating the role assignment might fail otherwise
Write-Output "Waiting 60 seconds for role assignment to be selectable. Please wait!"
Sleep -Seconds 60

# Add access for the AAD application on the subscription scope
New-AzureRmRoleAssignment -RoleDefinitionName "Contributor" -ServicePrincipalName $aadApplication.ApplicationId `
                          -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)"

# Add certificate to the Automation account
$secureCertificatePassword = $(ConvertTo-SecureString $selfsignedCertificatePlainPassword -AsPlainText -Force)
New-AzureRmAutomationCertificate -Name "AzureRunAsCertificate" -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                 -Path $pfxCertificatePath -Password $secureCertificatePassword -Exportable

# Create the automation connection
New-AzureRmAutomationConnection -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                -Name "AzureRunAsConnection" -ConnectionTypeName "AzureServicePrincipal" `
                                -ConnectionFieldValues @{"ApplicationId" = $aadApplication.ApplicationId; "TenantId" = $(Get-AzureRmContext).Tenant.Id; "CertificateThumbprint" = $pfxCertificateObject.Thumbprint; "SubscriptionId" = $(Get-AzureRmContext).Subscription.Id}

# Create the RunBook Automation Account
New-AzureRmAutomationRunbook -Name "RegulateVirtualMachineUptime" -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                             -Description "Regulates the virtual machines uptime." -Type "PowerShell"


Write-Output "Remember to save your password for the AAD Application somewhere safe. (Like in a Azure Key Vault). Your password is: $selfsignedCertificatePlainPassword"