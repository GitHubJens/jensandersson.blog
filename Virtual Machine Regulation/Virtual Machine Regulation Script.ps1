# Created by Jens Andersson - https://jensandersson.blog/:

# The name of the subscription you want to run the script on. This will speed up the iteration when you have lots of Subscriptions and VMs
param(
    [Parameter(Mandatory = $true)]
    [string] $subscriptionName = "SubscriptionName" 
)

# Change the country setting to implement other public holidays and 12h-days.
# Choose between "Norway", "Sweden" or "USA"
$countrySetting = "Norway"
$timeZone = "W. Europe Standard Time" # You can get your time zone from running this command on your local comp: $(Get-TimeZone).Id
$testRun = $true
$testRunVirtualMachineName = "DC01"

# Functions:
# Gets the difference between the time zone on the vm that the runbook is running on and the time zone that you are sending to the function
# This function is used in order to get the correct time even though you are running the runbook on a computer that is not in the same
# time zone as you are.
# Example: Get-CorrectTimeDifference "W. Europe Standard Time" => Returns 2
function Get-CorrectTimeDifference($timeZone)
{
    $timeSpanDifference = $(([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), [System.TimeZoneInfo]::Local.Id, $timeZone))) - $(Get-Date)
    return $timeSpanDifference.TotalHours
}

# Returns the date Martin Luther KIng Jr is celebrated on which is the third Monday in January
# Example of using the code: GetBirthdayOfMartinLutherKingJr "2018"
function GetBirthdayOfMartinLutherKingJr($year)
{
    $firstOfJanuary = $(Get-Date -Date "$year.01.01")
    $date = $firstOfJanuary
    $mondays = 0

    while($mondays -ne 3)
    {
        if(($date.DayOfWeek -eq "Monday") -and ($date.Month -eq 1))
        {
            $mondays++
        }

        if($mondays -ne 3)
        {
            $date = $date.AddDays(1)
        }
    }
    return $date
}

# Returns the date Inauguration Day is celebrated on which is the 20th of January if not this is a Sunday, then it is on the 21th
# Example of using the code: GetInaugurationDay "2018"
function GetInaugurationDay($year)
{
    $date = (Get-Date -Year $year -Month 01 -Day 20)

    if($date.DayOfWeek -ne "Sunday")
    {
        return $date
    }
    else
    {
        return $date.AddDays(1)
    }
}

# Returns the date Washingtons Birthday is celebrated on which is the third Monday in Feburary
# Example of using the code: GetWashingtonsBirthday "2018"
function GetWashingtonsBirthday($year)
{
    $firstOfFebruary = $(Get-Date -Date "$year.02.01")
    $date = $firstOfFebruary
    $mondays = 0

    while($mondays -ne 3)
    {
        if(($date.DayOfWeek -eq "Monday") -and ($date.Month -eq 2))
        {
            $mondays++
        }

        if($mondays -ne 3)
        {
            $date = $date.AddDays(1)
        }
    }
    return $date
}

# Returns the date Memorial Day is celebrated on which is the last Monday in May
# Example of using the code: GetMemorialDay "2018"
function GetMemorialDay($year)
{
    $firstOfJune = $(Get-Date -Date "$year.06.01")
    $date = $firstOfJune
    $mondays = 0

    while($mondays -ne 1)
    {
        if(($date.DayOfWeek -eq "Monday") -and ($date.Month -eq 5))
        {
            $mondays++
        }

        if($mondays -ne 1)
        {
            $date = $date.AddDays(-1)
        }
    }
    return $date
}

# Returns the date labor day is celebrated on which is the first Monday in September
# Example of using the code: GetLaborDay "2018"
function GetLaborDay($year)
{
    $firstOfSeptember = $(Get-Date -Date "$year.09.01")
    $date = $firstOfSeptember
    $mondays = 0

    while($mondays -ne 1)
    {
        if($date.DayOfWeek -eq "Monday")
        {
            $mondays++
        }

        if($mondays -ne 1)
        {
            $date = $date.AddDays(1)
        }
    }
    return $date
}

# Returns the date columbus day is celebrated on which is the second Monday in October
# Example of using the code: GetColumbusDay "2010"
function GetColumbusDay($year)
{
    $firstOfOctober = $(Get-Date -Date "$year.10.01")
    $date = $firstOfOctober
    $mondays = 0

    Do
    {
        if($date.DayOfWeek -eq "Monday")
        {
            $mondays++
        }

        if($mondays -ne 2)
        {
            $date = $date.AddDays(1)
        }
    }
    Until($mondays -eq 2)

    return $date
}

# Example: GetAllDatesInAnInterval "1may-17may"
# Returns an array of all the dates in between an intervall of dates.
function GetAllDatesInAnInterval($dates)
{
    if($dates.Contains("-"))
    {
        $returnDates = @()
        $startDate = $(Get-Date $dates.Split("-")[0])
        $endDate = $(Get-Date $dates.Split("-")[1])

        while($startDate -le $endDate)
        {
            $returnDates += $startDate
            $startDate = $startDate.AddDays(1)
        }
    }
    return $returnDates
}

# Returns the date for ThanksGiving for the $year
function Get-ThanksGivingDate($year)
{
    $date = $(Get-Date "November 1, $year")

    if((Get-Date "November 1, $year").DayOfWeek -ne "Thursday")
    {
        return (Get-Date "November 1, $year").AddDays(22)
    }
    else
    {
        return (Get-Date "November 1, $year").AddDays(21)
    }
}

# Returns the first day of easter for the given year
function Get-FirstDayOfEaster($year)
{
    $a = $year % 19
    $b = $year % 100
    $c = ($year - $b) / 100
    $e = $c % 4
    $d = ($c - $e) / 4
    $f = [math]::floor(($c + 8) / 25)
    $g = [math]::floor(($c - $f + 1) / 3)
    $h = (19 * $a + $c - $d - $g + 15) % 30
    $k = $b % 4
    $i = ($b - $k) / 4
    $l = (32 + 2 * $e + 2 * $i - $h - $k) % 7
    $m = [math]::floor(($a + 11 * $h + 22 * $l) / 451)
    $p = ($h + $l - 7 * $m + 114) % 31
    $n = (($h + $l - 7 * $m + 114) - $p) / 31
    return New-Object DateTime $year, $n, ($p+1)
}

# Returns the second day of easter
function Get-SecondDayOfEaster($year)
{
    return (Get-FirstDayOfEaster $year).AddDays(1)
}

# Return the Good Friday of the year
function Get-GoodFriday($year)
{
    return (Get-FirstDayOfEaster $year).AddDays(-2)
}

# Returns the Good Thursday of the year
function Get-GoodThursday($year)
{
    return (Get-FirstDayOfEaster $year).AddDays(-3)
}

# Returns the Palm Sunday of the year
function Get-PalmSunday($year)
{
    return (Get-FirstDayOfEaster $year).AddDays(-7)
}

# Returns Swedish paskafton of the year
function Get-PaskAfton($year)
{
    return (Get-GoodFriday $year).AddDays(1);
}

# Returns the Swedish holiday Annandag Pask
function Get-AnnanDagPask($year)
{
    return (Get-FirstDayOfEaster $year).AddDays(1);
}

# Returns the Swedish data for Kristihimmelfartsdag
function Get-Kristihimmelfardsdag($year)
{
    $paskdagen = Get-FirstDayOfEaster $year
    $date = $paskdagen
    $thursdays = 0

    while($thursdays -ne 6)
    {
        if($date.DayOfWeek -eq "Thursday")
        {
            $thursdays++
        }

        if($thursdays -ne 6)
        {
            $date = $date.AddDays(1)
        }
    }
    return $date
}

# Returns the date for the Swedish holiday Pingstdagen
function Get-PingstDagen($year)
{
    $paskdagen = Get-FirstDayOfEaster $year
    $date = $paskdagen
    $sundays = 0

    if($paskdagen.DayOfWeek -eq "Sunday")
    {
        $sundaysAfterPaskdagen = 8
    }
    else
    {
        $sundaysAfterPaskdagen = 7
    }

    while($sundays -ne $sundaysAfterPaskdagen)
    {
        if($date.DayOfWeek -eq "Sunday")
        {
            $sundays++
        }

        if($sundays -ne $sundaysAfterPaskdagen)
        {
            $date = $date.AddDays(1)
        }
    }
    return $date
}

# Returns the Swedish public holiday midsommardagen
function Get-Midsommardagen($year)
{
    $20thOfJune = $(Get-Date -Date "$year.06.20")
    $date = $20thOfJune
    $saturdays = 0

    while($saturdays -ne 1)
    {
        if($date.DayOfWeek -eq "Saturday")
        {
            $saturdays++
        }

        if($saturdays -ne 1)
        {
            $date = $date.AddDays(1)
        }
    }
    return $date
}

# Returns the Swedish public holiday Alla Helgons Dag
function Get-AllaHelgonsDag($year)
{
    $lastOctober = $(Get-Date -Date "$year.10.31")
    $date = $lastOctober
    $saturdays = 0

    while($saturdays -ne 1)
    {
        if($date.DayOfWeek -eq "Saturday")
        {
            $saturdays++
        }

        if($saturdays -ne 1)
        {
            $date = $date.AddDays(1)
        }
    }
    return $date
}

# Variables:
$dayOfWeek = (Get-Date).DayOfWeek
$addHours = Get-CorrectTimeDifference $timeZone

if($countrySetting -eq "Norway")
{
    # Holidays for Norway
    $holidays = @{
                  "forstenyttarsdag" = $(Get-Date "1 january");
                  "palmesondag" = Get-PalmSunday $(Get-Date).Year;
                  "skjaertorsdag" = Get-GoodThursday $(Get-Date).Year;
                  "langfredag" = Get-GoodFriday $(Get-Date).Year;
                  "forstepaskedag" = Get-FirstDayOfEaster $(Get-Date).Year;
                  "andrepaskedag" = Get-SecondDayOfEaster $(Get-Date).Year;
                  "forstemai" = $(Get-Date "1 may");
                  "kristihimmelfartsdag" = $(Get-Date "10 may");
                  "grunnlovsdagen" = $(Get-Date "17 may");
                  "forstepinsedag" = $(Get-Date "20 may");
                  "andrepinsedag" = $(Get-Date "21 may");
                  "forstejuledag" = $(Get-Date "25 december");
                  "andrejuledag" = $(Get-Date "26 december")
                 }
}
elseif($countrySetting -eq "USA")
{
    # Holidays for USA
    $holidays = @{
                  "newyearsday" = $(Get-Date "1 january");
                  "birthdayofmartinlutherkingjr" = GetBirthdayOfMartinLutherKingJr $(Get-Date).Year;
                  "inaugurationday" = Get-SecondDayOfEaster $(Get-Date).Year;
                  "washingtonsbirthday" = GetWashingtonsBirthday $(Get-Date).Year;
                  "memorialday" = GetMemorialDay $(Get-Date).Year;
                  "independenceday" = $(Get-Date "4 july");
                  "laborday" = GetLaborDay $(Get-Date).Year;
                  "columbusday" = GetColumbusDay $(Get-Date).Year;
                  "veteransday" = $(Get-Date "11 november");
                  "thanksgiving" = Get-ThanksGivingDate $(Get-Date).Year;
                  "christmas" = $(Get-Date "25 december")
                 }
}
elseif($countrySetting -eq "Sweden")
{
    # Holidays for Sweden
    $holidays = @{
                  "nyarsdagen" = $(Get-Date "1 january");
                  "trettondagsafton" = $(Get-Date "5 january");
                  "trettondedagjul" = $(Get-Date "6 january");
                  "langfredagen" = Get-GoodFriday (Get-Date).Year;
                  "paskdagen" = Get-FirstDayOfEaster $(Get-Date).Year;
                  "paskafton" = Get-PaskAfton $(Get-Date).Year;
                  "annandagpask" = Get-AnnanDagPask $(Get-Date).Year;
                  "forstamaj" = $(Get-Date "1 may");
                  "kristihimmelfardsdag" = Get-Kristihimmelfardsdag $(Get-Date).Year;
                  "pingstdagen" = Get-PingstDagen $(Get-Date).Year;
                  "sverigesnationaldag" = $(Get-Date "6 june");
                  "midsommardagen" = Get-Midsommardagen $(Get-Date).Year;
                  "allahelgonsdag" = $(Get-Date "21 may");
                  "juldagen" = $(Get-Date "25 december");
                  "annandagjul" = $(Get-Date "26 december")
                 }
}

# Automatically build the list for the tag "notonlinedays" based on the $holidays variable.
$notOnlineDays = ""
$count = 0
$holidays.Keys | foreach { `
                            $count++
                            if($count -ne $holidays.Keys.Count)
                            {
                                $notOnlineDays += "$_;"
                            }
                            else
                            {
                                $notOnlineDays += "$_"
                            }
                         }

# Build the standard time for startup and shutdown based on the choosen $countrySetting, since USA doesn't implement the 24hour clock like Norway and Sweden
if($countrySetting -eq "USA")
{
    $startupTime = "9AM"
    $shutdownTime = "5PM"
}
else
{
    $startupTime = "09:00"
    $shutdownTime = "17:00"
}

# Login into Azure Resource Manager - Remember that you need to create an automation account.
$automationConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'
Login-AzureRMAccount -ServicePrincipal -Tenant $automationConnection.TenantID -ApplicationId $automationConnection.ApplicationID `
                     -CertificateThumbprint $automationConnection.CertificateThumbprint | Out-Null

# Information about this being a test run and which Subscriptions being affected:
if($testRun)
{
    Write-Output "TEST RUN IS ACTIVATED!"
    Write-Output "The following Subscriptions would be affected by the script:"
    (Get-AzureRmSubscription).Name
    Write-Output "If you can't see all subscriptions this is because you have not given the Run As Account access to all of them."
    Write-Output "The following Virtual Machines will be affected by the script:"
    (Get-AzureRmVM -Status | Where-Object { $_.Name -eq $testRunVirtualMachineName }).Name
}

foreach($subscription in Get-AzureRmSubscription | Where-Object { $_.Name -eq $subscriptionName })
{
    $automationConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'
    Login-AzureRMAccount -ServicePrincipal -Tenant $automationConnection.TenantID -ApplicationId $automationConnection.ApplicationID `
                         -CertificateThumbprint $automationConnection.CertificateThumbprint -Subscription $subscription.Name | Out-Null

    # Forces all the virtual machines to implement the tags if they are not already doing it.
    foreach($vm in Get-AzureRmVM -Status | Where-Object { $_.ProvisioningState -ne "Failed" })
    {
        if(!$testRun -or ($testRun -and ($vm.Name -eq $testRunVirtualMachineName)))
        {
            $tags = $vm.Tags
            if(-not($vm.Tags.ContainsKey("notonlinedays"))){$tags += @{notonlinedays=$notOnlineDays}}
            if(-not($vm.Tags.ContainsKey("onlinedays"))){$tags += @{onlinedays="monday;tuesday;wednesday;thursday;friday"}}
            if(-not($vm.Tags.ContainsKey("shutdown"))){$tags += @{shutdown=$shutdownTime}}
            if(-not($vm.Tags.ContainsKey("startup"))){$tags += @{startup=$startupTime}}
            if(-not($vm.Tags.ContainsKey("ignoreshutdown"))){$tags += @{ignoreshutdown="no"}}
            Set-AzureRmResource -ResourceId $vm.Id -Tag $tags -Force
        }
    }

    # Iterating through all the virtual machines of the solution:
    foreach($virtualMachine in Get-AzureRmVM -Status)
    {
        if(!$testRun -or ($testRun -and ($virtualMachine.Name -eq $testRunVirtualMachineName)))
        {
            $shutdownDueToNotOnlineDay = $false
            $ignoreShutdown = $false

            # If the virtual machine implements the tag ignoreshutdown and it is set to "yes" the script will skip this machine
            if($virtualMachine.Tags.ContainsKey("ignoreshutdown"))
            {
                if($virtualMachine.Tags.ignoreshutdown -eq "yes")
                {
                    $ignoreShutdown = $true
                }
            }

            if(-not($ignoreShutdown))
            {
                # Only run code on machines that are not in failed state:
                if($virtualMachine.ProvisioningState -ne "Failed")
                {
                    # If the virtual machine has the tag for holidays it shouldn't be online we will check if today is one of those days and then shut it down.
                    if($virtualMachine.Tags.ContainsKey("notonlinedays"))
                    {
                        $arrayOfNotOnlineDays = $virtualMachine.Tags.notonlinedays.Split(";")
                        foreach($day in $arrayOfNotOnlineDays)
                        {
                            if($holidays.ContainsKey($day))
                            {
                                if($holidays."$day" -eq (Get-Date).Date)
                                {
                                    if($virtualMachine.PowerState -eq "VM running")
                                    {
                                        # Run this as a job so that we can iterate through the other vms at the same time.
                                        Write-Output "Stopping the virtual machine: $($virtualMachine.Name), because it contains the notonlinedays:$day which means it will not be up on: $((Get-Date).Date)"
                                        Stop-AzureRmVM -Name $virtualMachine.Name -ResourceGroupName $virtualMachine.ResourceGroupName -Force -AsJob
                                    }
                                    $shutdownDueToNotOnlineDay = $true
                                }
                            }
                            elseif($day.Contains("-"))
                            {
                                $dates = GetAllDatesInAnInterval $day
                                if($dates.Contains((Get-Date).Date))
                                {
                                    if($virtualMachine.PowerState -eq "VM running")
                                    {
                                        # Run this as a job so that we can iterate through the other vms at the same time.
                                        Write-Output "Stopping the virtual machine: $($virtualMachine.Name), because it contains the notonlinedays:$day which means it will not be up on: $((Get-Date).Date)"
                                        Stop-AzureRmVM -Name $virtualMachine.Name -ResourceGroupName $virtualMachine.ResourceGroupName -Force -AsJob
                                    }
                                    $shutdownDueToNotOnlineDay = $true
                                }
                            }
                        }
                    }
                    else
                    {
                        Write-Output "$($virtualMachine.Name) does not implement the tag `"notonlinedays`"!"
                    }

                    # If the virtual machine is not shutting down due to the present day being in the list of holidays we will continue with the rest of the script
                    if(-not($shutdownDueToNotOnlineDay))
                    {
                        if($virtualMachine.Tags.ContainsKey("onlinedays"))
                        {
                            # Get array of days that the vm should be online
                            $arrayOfOnlineDays = $(($virtualMachine.Tags.onlinedays).Split(";"))

                            # Power off if the machine should'nt be online.
                            if(((Get-Date).DayOfWeek) -notin $arrayOfOnlineDays)
                            {
                                if($virtualMachine.PowerState -eq "VM running")
                                {
                                    # Run this as a job so that we can iterate through the other vms at the same time.
                                    Write-Output "Stopping the virtual machine: $($virtualMachine.Name), because it is in `"VM running`"-state, the day is $((Get-Date).DayOfWeek) and the tag onlinedays does not contain this day."
                                    Stop-AzureRmVM -Name $virtualMachine.Name -ResourceGroupName $virtualMachine.ResourceGroupName -Force -AsJob
                                }
                            }
                            else
                            {
                                if($virtualMachine.Tags.ContainsKey("startup"))
                                {
                                    if($virtualMachine.PowerState -eq "VM deallocated")
                                    {
                                        if(((Get-Date $virtualMachine.Tags.startup) -lt (Get-Date).AddHours($addHours)) -and ((Get-Date $virtualMachine.Tags.shutdown) -gt (Get-Date).AddHours($addHours)))
                                        {
                                            # Run this as a job so that we can iterate through the other vms at the same time.
                                            Write-Output "Starting the virtual machine: $($virtualMachine.Name), because its startup tag tells it to start $($virtualMachine.Tags.startup) and the time is now: $((Get-Date).AddHours($addHours))"
                                            Start-AzureRmVM -Name $virtualMachine.Name -ResourceGroupName $virtualMachine.ResourceGroupName -AsJob
                                        }
                                    }
                                }
                                else
                                {
                                    Write-Output "$($virtualMachine.Name) does not implement the tag `"startup`"!"
                                }

                                if($virtualMachine.Tags.ContainsKey("shutdown"))
                                {
                                    if($virtualMachine.PowerState -eq "VM running")
                                    {
                                        # Initiating the shutdown if the time is greater than what is setup on the virtual machine tag for shutdown.
                                        if((Get-Date $virtualMachine.Tags.shutdown) -lt (Get-Date).AddHours($addHours))
                                        {
                                            # Run this as a job so that we can iterate through the other vms at the same time.
                                            Write-Output "Stopping the virtual machine: $($virtualMachine.Name), because its shutdown tag tells it to stop $($virtualMachine.Tags.shutdown) and the time is now: $((Get-Date).AddHours($addHours))"
                                            Stop-AzureRmVM -Name $virtualMachine.Name -ResourceGroupName $virtualMachine.ResourceGroupName -Force -AsJob
                                        }
                                    }
                                }
                                else
                                {
                                    Write-Output "$($virtualMachine.Name) does not implement the tag `"shutdown`"!"
                                }
                            }
                        }
                        else
                        {
                            Write-Output "$($virtualMachine.Name) does not implement the tag `"onlinedays`"!"
                        }
                    }
                }
                else
                {
                    Write-Output "Skipping iteration on the virtual machine: $($virtualMachine.Name), because it is in `"Failed`" ProvisioningState"
                }
            }
            else
            {
                Write-Output "Skipping iteration on the virtual machine: $($virtualMachine.Name), because it is implementing ignoreshutdown tag with the value `"yes`""
            }
        }
    }

    # Waiting for all the jobs to finish and finally cleaning up
    foreach($job in Get-Job)
    {
        $jobState = $job.State
        while($jobState -eq "Running")
        {
            Write-Output "Waiting 30seconds for jobs to finish. Jobs left: $((Get-Job | Where-Object { $_.State -eq "Running" }).Count)"
            Sleep -Seconds 30
            $jobState = (Get-Job -id $job.Id).State
        }
        $job | Receive-Job
    }
    Get-Job | Remove-Job -Force
}
