# Created by Jens Andersson - https://jensandersson.blog/

# 1. Publish the RunBook
# 2. Creates a new RunBook Automation Schedule which will run the code every hour
# 3. Register the shcedule with the RunBook.

# Parameters that you need to change:
$resourceGroupName = "Enter the name of the Resource Group you want the solution to be placed in." # Eg. jaautomationrg
$automationAccountName = "Enter the name of the Automation Account you want to crate." # Eg. jaauto

# Publish the RunBook
Publish-AzureRmAutomationRunbook –AutomationAccountName $automationAccountName –Name "RegulateVirtualMachineUptime" -ResourceGroupName $resourceGroupName

foreach($subscription in Get-AzureRmSubscription)
{
    # Add a schedule to the RunBook so that it runs every hour
    New-AzureRmAutomationSchedule -Name "$($subscription.Name)-Hourly" -Description "Runs every hour and never stops" -AutomationAccountName $automationAccountName `
                                  -StartTime $(Get-Date).AddMinutes(-$(Get-Date).Minute % 60).AddSeconds(-$(Get-Date).Second % 60).AddHours(1) -HourInterval 1 `
                                  -ResourceGroupName $resourceGroupName -TimeZone (Get-TimeZone).Id

    # Register schedule with RunBook
    Register-AzureRmAutomationScheduledRunbook -RunbookName "RegulateVirtualMachineUptime" -ResourceGroupName $resourceGroupName -ScheduleName "$($subscription.Name)-Hourly" `
                                               -AutomationAccountName $automationAccountName -Parameters @{ subscriptionName = $subscription.Name }
}