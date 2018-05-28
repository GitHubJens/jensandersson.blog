# 1. Creates a new Resource Group is there isn't one already
# 2. Creates a new Automation Account
# 3. Creates a new AAD Application
# 4. Creates a new Self Signed Certificate
# 5. Sets up the AAD Application Credentials using the Certificate
# 6. Creates a Service Principal for the AAD Application
# 7. Gives the Run As Account (The AAD Application) contributor access to the Subscription
# 8. Upload the Certificate to the Automation Account
# 9. Create a new Automation Connection for the Automation Account

# Parameters that you need to change:
$subscription = "ifnodclab"
$resourceGroupName = "jaautomationrg"
$automationAccountName = "jaauto"
$location = "West Europe"
$selfsignedCertificatePlainPassword = "YourPasswordForTheSelfsignedCertificate"
$certificateLifetimeInMonths = 12
$aadApplicationName = "jaautomationaadapp"

# Make sure the script is ran as an Administrator, otherwise this fails when creating certificates:
if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    Write-Error "You need to start the script as an administrator!"
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

# Create Self Signed Certificate that is used for the AAD application and Export it:
$selfsignedCertificate = New-SelfSignedCertificate -DnsName "$automationAccountName`AzureRunAsCertificate" -CertStoreLocation "Cert:\CurrentUser\My" `
                                                   -KeyExportPolicy "Exportable" -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
                                                   -NotAfter (Get-Date).AddMonths($certificateLifetimeInMonths) -HashAlgorithm "SHA256"

$certificateThumbprint = (Get-ChildItem -Path "Cert:\CurrentUser\My\" | Where-Object { $_.Subject -eq "CN=$automationAccountName`AzureRunAsCertificate" }).Thumbprint
$secureCertificatePassword = $(ConvertTo-SecureString $selfsignedCertificatePlainPassword -AsPlainText -Force)
$pfxCertificatePath = "$env:Temp\$automationAccountName`AzureRunAsCertificate.pfx"

Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$certificateThumbprint" `
                      -FilePath $pfxCertificatePath `
                      -Password $secureCertificatePassword -Force

$pfxCertificateObject = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($pfxCertificatePath, $selfsignedCertificatePlainPassword)
$pfxCertificateValue = [System.Convert]::ToBase64String($pfxCertificateObject.GetRawCertData())

# Add the certificate to the AAD Application
New-AzureRmADAppCredential -ApplicationId $aadApplication.ApplicationId -CertValue $pfxCertificateValue `
                           -StartDate $pfxCertificateObject.GetEffectiveDateString() `
                           -EndDate $(Get-Date $pfxCertificateObject.GetExpirationDateString()).AddDays(-1)

# Create Service Principal for the Run As Account:
New-AzureRmADServicePrincipal -ApplicationId $aadApplication.ApplicationId

# Sleeping a minute since creating the role assignment might fail otherwise
Sleep -Seconds 60

# Add access for the AAD application on the subscription scope
New-AzureRmRoleAssignment -RoleDefinitionName "Contributor" -ServicePrincipalName $aadApplication.ApplicationId `
                          -Scope "/subscriptions/$((Get-AzureRmContext).Subscription.Id)"

# Add certificate to the Automation account
New-AzureRmAutomationCertificate -Name "AzureRunAsCertificate" -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                 -Path $pfxCertificatePath -Password $secureCertificatePassword -Exportable

# Create the automation connection
New-AzureRmAutomationConnection -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                -Name "AzureRunAsConnection" -ConnectionTypeName "AzureServicePrincipal" `
                                -ConnectionFieldValues @{"ApplicationId" = $aadApplication.ApplicationId; "TenantId" = $(Get-AzureRmContext).Tenant.Id; "CertificateThumbprint" = $pfxCertificateObject.Thumbprint; "SubscriptionId" = $(Get-AzureRmContext).Subscription.Id}