# FEEL FREE TO MODIFY OR DISTRIBUTE YOUR OWN VERSION, BUT PLEASE DON'T REMOVE THIS -->
# DEVELOPED BY JENS ANDERSSON
# - BLOG: HTTPS://JENSANDERSSON.BLOG
# - EMAIL: jensandersson87@gmail.com
# - PRINCIPAL CLOUD SOLUTIONS ARCHITECT AND MICROSOFT PTSP @ INNOFACTOR NORWAY
# <--- FEEL FREE TO MODIFY OR DISTRIBUTE YOUR OWN VERSION, BUT PLEASE DON'T REMOVE THIS

# DOCUMENTATION:
# Downloads logs from Microsoft Cloud App Security. The logs are stores as json files
# on your file system so that you are able to load them into any other application.
# Choose between GetAll or Delta functionality. The script will either download all the
# logs available on MCAS or just the delta since your last syncrhonization. In order
# for the solution to be as fast as possible you will have to create on API key for each
# PowerShell job as well as have the script offload the downloaded json as json-files which
# it writes to your file system.

# How to:
# You create a CAS API Token from the Cloud App Security site. Eg. 
# https://<customerName>.portal.cloudappsecurity.com/#/dashboard --> Top Right Corner Cog-Wheel 
# --> Security Extensions --> Press + to create new API Token
# It is easiest if you run the script with $collectLogsFromThisDate = "GetAll" the first time
# When you run it this way it will get every log that is present in the system and in the
# end it will create a json file which tells the script at which date and time it should
# start downloading the logs next time it is running.

# Performance Data:
# Collects 12500 logs per minute if you have 35 API Keys in the $tokens array variable.
# Sometimes the API can be less responsive than other times.
# It is not possible to retrive more than 100 logs per API call so you will have to do many
# at the same time as you manage the throttling, server and gateway limits

Param(
    [parameter(Mandatory = $false, HelpMessage = "The CAS portal URL - Eg. <customerName>.portal.cloudappsecurity.com")]
    [ValidateNotNullOrEmpty()]
    [string]$portalUrl = "customerName.portal.cloudappsecurity.com",

    [parameter(Mandatory = $false, HelpMessage = "The API Key for the CAS solution. Each key has a limit of 30 requests per minute and the ultimate number seems to be 35 keys.")]
    [ValidateNotNullOrEmpty()]
    [array]$tokens = @("tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==", 
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS2==", 
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS3==", 
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS4==", 
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS5==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1==",
                       "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1=="),

    [parameter(Mandatory = $false, HelpMessage = "GetAll = Collects all from this date to the beginning, Delta = Collects everything new since the last run")]
    [ValidateNotNullOrEmpty()]
    [string]$collectLogsFromThisDate = "GetAll",

    [parameter(Mandatory = $false, HelpMessage = "Path where all the logs are output as json files.")]
    [ValidateNotNullOrEmpty()]
    [string]$outputFilepath = "C:\CASLogs_vNext\Logs",

    [parameter(Mandatory = $false, HelpMessage = "Path that is used for storing a file with the latest fetched log timestamp")]
    [ValidateNotNullOrEmpty()]
    [string]$latestFetchedLogTimestampFilepath = "C:\CASLogs_vNext\Settings"
)

#############
# FUNCTIONS #
#############
# Gives you the UNIX timestamp from the Get-Date object (Milliseconds)
# Example:
# $dateTime = (Get-Date -Year 2018 -Month 11 -Day 29 -Hour 12 -Minute 07 -Second 16 -Millisecond 483)
# Returns: 1543493236483
function Get-UnixTimestampFromNormalTime($dateTime)
{
    return [int64](New-TimeSpan -Start (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 1 -Minute 0 -Second 0 -Millisecond 0).ToUniversalTime() -End $dateTime).TotalMilliseconds
}

# Gives you the normal time from a UNIX timestamp (Milliseconds)
# Example:
# $unixTimeStamp = 1543493236483
# Returns: [DateTime] object: torsdag 29. november 2018 12:07:16:483
function Get-NormalTimeFromUnixTimestamp($unixTimeStamp)
{
    return Get-Date((Get-Date -Year 1970 -Month 1 -Day 1 -Hour 1 -Minute 0 -Second 0 -Millisecond 0).ToUniversalTime().AddMilliseconds($unixTimeStamp)) -Format yyyyMMddHHmmssfff
}

# Returns a datetime object from a string
# Example: 
# $dateTimeString = 20181129130716483 
# Returns: Get-Date -Year 2018 -Month 11 -Day 29 -Hour 12 -Minute 07 -Second 16 -Millisecond 483
function Get-DateTimeFromString($dateTimeString)
{
    return Get-Date -Year $dateTimeString.Substring(0,4) -Month $dateTimeString.Substring(4,2) -Day $dateTimeString.Substring(6,2) -Hour $dateTimeString.Substring(8,2) -Minute $dateTimeString.Substring(10,2) -Second $dateTimeString.Substring(12,2) -Millisecond $dateTimeString.Substring(14,3)
}

# Returns the total number of logs that a query to MCAS returns. 
# This is used so that we can create jobs for parallell REST calls as well as for estimation of run time.
# Example:
# $token = "tGGTJ0hT8WoEZZhbkXESK4XFRQZHf1NHOZX0FNwFQ5pxUGKXMMg1SHT0fAhkGFgOXZGHF1NJWUkUXQBHkxbSGotkYEks0BRc5xGTEcZxM9dE4HLgkafekTLH8FHVGFTKKUFb9k0wpUNxS1"
# $portalUrl = "customerName.portal.cloudappsecurity.com"
# $jsonBody = "{`"skip`": `"0`",`"limit`": `"100`", `"filters`":{ `"date`": {`"gte`": 20181129130716483 } } }"
# Returns: 80475
function Get-TotalNumberOfLogsThatQueryReturns($token, $portalUrl, $startJsonBody)
{
    do
    {
        $retryCall = $false
        try 
        {
            # Run the REST call against CAS, getting the logs
            $response = Invoke-RestMethod -Method "Post" `
                                            -Headers @{Authorization = "Token $token"} `
                                            -Uri "https://$portalUrl/api/v1/activities/" `
                                            -ContentType "application/json" `
                                            -UseBasicParsing `
                                            -Body $startJsonBody `
                                            -Verbose
    
            # Convert the fetched logs to a JSON Object
            do
            {
                $convertedToJson = $false
                try
                {
                    # Sometimes this is already a object, therefore we check this before trying to convert it
                    if($response.GetType().Name -ne "PSCustomObject")
                    {
                        $response = $response | ConvertFrom-Json
                    }
                    else
                    {
                        Write-Verbose "Response were already a PSObject, skipping conversion."
                    }
                    $convertedToJson = $true
                }
                catch
                {
                    if($_.Exception -like "*contains the duplicated keys*")
                    {

                        # Remove duplicate keys since you won't be able to convert to Json
                        $errorMessage = $_.Exception
                        $duplicateKeyOne = $errorMessage.ToString().Split("'")[1]
                        $duplicateKeyTwo = $errorMessage.ToString().Split("'")[3]
                        $response = $response.Replace("$duplicateKeyOne","$duplicateKeyTwo")
                        Write-Verbose "Changed duplicate keys ($duplicateKeyOne => $duplicateKeyTwo) since it wasn't possible to convert the object to JSON"
                    }
                }
            }
            until($convertedToJson)
        }
        catch
        {
            if($_.Exception.Message -like "429")
            {
                $retryCall = $true
                Write-Warning "429 - Too many requests. The MCAS API throttling limit has been hit, the call will be retried in 3 second(s)..."
                Write-Verbose "Sleeping for 3 seconds"
                Start-Sleep -Seconds 3
            }
            elseif($_.Exception.Message -like "*500*")
            {
                $retryCall = $true
                Write-Warning "500 - Server Error..."
                Write-Verbose "Sleeping for 3 seconds"
                Start-Sleep -Seconds 3
            }
            elseif($_.Exception.Message -like "*504*")
            {
                $retryCall = $true
                Write-Warning "504 - Gateway Timeout. The call will be retried in 3 second(s)..."
                Write-Verbose "Sleeping for 3 seconds"
                Start-Sleep -Seconds 3
            }
            elseif($_.Exception.Message -like "*Request was throttled. Expected available in*")
            {
                # Activate retry
                $retryCall = $true

                # Create json object from error output:
                $json = '{\"detail\":\"Request was throttled. Expected available in 5.0 seconds.\"}'
                $json = $json.Replace("\","")
                $json = $json | ConvertFrom-Json

                # Parse the time you need to wait until re-running the API Call
                $waitTime = [Math]::Round(($json.detail).Split(" ")[($json.detail).Split(" ").Count - 2], 0)

                # Wating the required time
                Write-Warning "Request was throttled. The call will be retried in $waitTime second(s)..."
                Write-Verbose "Sleeping for $waitTime seconds"
                Start-Sleep -Seconds $waitTime
            }
            else
            {
                throw $_
            }
        }
    }
    while ($retryCall)

    return $response.total
}

# Fucntion that makes sure you don't create more than the $maxNumberOfSimultaneousJobs jobs.
# If the max amoun tof jobs is reached the fucntion will wait 3seconds and check again, until 
# the number of running jobs is lower than the $maxNumberOfSimultaneousJobs
# Send $maxNumberOfSimultaneousJobs = 0 if you want to wait for all jobs.
function Wait-ForJobs($maxNumberOfSimultaneousJobs)
{
    # Wait for jobs if the maximum number of jobs have been reached
    $jobs = Get-Job
    if($jobs.Count -ge $maxNumberOfSimultaneousJobs)
    {
        Write-Verbose "Waiting for jobs to finish. Currently $($jobs.Count) jobs running... (Max number of jobs have been reached: $maxNumberOfSimultaneousJobs)"
        do
        {
            Sleep -Seconds 1

            # Cleanup the jobs that have been finished
            $jobs = Get-Job
            foreach($job in $jobs)
            {
                # Get all data from the ones that didn't fail
                if($job.HasMoreData -and ($job.State -eq "Completed"))
                {
                    $job | Receive-Job
                    $job | Remove-Job
     
                    Write-Host "Job: `"$($job.Name)`" successfully completed." -ForegroundColor Green
                }

                # Get all data from the ones that didn't fail
                if($job.State -eq "Failed")
                {
                    $job | Receive-Job
                    $job | Remove-Job
                    Write-Host "Job: `"$($job.Name)`" failed!" -ForegroundColor Red
                }
            }
        }
        while($jobs.Count -gt $maxNumberOfSimultaneousJobs)
    }
}

###################
# INITIALIZATIONS #
###################
# Create paths that are needed:
if(!(Test-Path $latestFetchedLogTimestampFilepath))
{
    New-Item -Path $latestFetchedLogTimestampFilepath -ItemType Directory
}
if(!(Test-Path $outputFilepath))
{
    New-Item -Path $outputFilepath -ItemType Directory
}

# Change the date depending on the functinoality selected
if($collectLogsFromThisDate -eq "GetAll")
{
    Write-Host "GetAll synchronization is activated. The script will get all the logs."
    $collectLogsFromThisDate = "20000101010101000" # This means it will get everything since 2000, which is everything in your solution
}
elseif($collectLogsFromThisDate -eq "Delta")
{
    if(Test-Path "$latestFetchedLogTimestampFilepath\latestFetchedLogTimestamp.json")
    {
        $latestFetchedLogTimestampFileContents = (Get-Content -Path "$latestFetchedLogTimestampFilepath\latestFetchedLogTimestamp.json") | ConvertFrom-Json
        $collectLogsFromThisDate = $latestFetchedLogTimestampFileContents.latestFetchedLogTimestamp
        Write-Host "Delta synchronization is activated. The script will get all the logs since $collectLogsFromThisDate."
    }
    else
    {
        Write-Error "You have activated delta synchronization but the script couldn't find any latestFetchedLogTimestamp.json file! This functionality require you to run the full synchronization first since it is depending on a file which tells the script from what time is should start collecting the logs."
        PAUSE
        Throw
    }
}

################
#  VARIABLES   #
################
# USED FOR CALCULATION OF STARTTIME FOR QUERIES:
$collectLogsFromThisDateDateTime = Get-DateTimeFromString $collectLogsFromThisDate # If nothing is sent to this script parameter it will use January 2015 (Fetching all logs)
$collectLogsFromThisDateUnix = Get-UnixTimestampFromNormalTime $collectLogsFromThisDateDateTime
$collectLogsFromThisDateUnixFinal = $collectLogsFromThisDateUnix + 1 # Add a millisecond so we get newer logs than last synchronization. Otherwise we get duplicates

# USED FOR CALCULATING JOB NUMBER AND ESTIMATIONS:
# Date gte: From this date
# Date lte: To this date
if($collectLogsFromThisDate -eq "GetAll")
{
    $startJsonBody = "{`"skip`": 0,`"limit`": 100 }"
}
else
{
    $startJsonBody = "{`"skip`": 0,`"limit`": 100, `"filters`":{ `"date`": {`"gte`": $collectLogsFromThisDateUnixFinal } } }"
}
$numberOfLogsReturnedByQuery = Get-TotalNumberOfLogsThatQueryReturns -token $tokens[0] -portalUrl $portalUrl -startJsonBody $startJsonBody
$numberOfjobs = [Math]::Ceiling($numberOfLogsReturnedByQuery / 100) # Rounded up so we get the last job which won't be producing as many logs as the other ones

# JOBS LOGICAL VARIABLES:
$maxNumberOfSimultaneousJobs = $tokens.Count # This is the maximum number of jobs that are allowed to run simultaniously

# DEBUG
$VerbosePreference = "continue"
$timer = [system.diagnostics.stopwatch]::StartNew()

################
# SCRIPT START #
################
# Fetch $maxNumberOfLogsPerFetch logs from Cloud App Security (+ Retry if it hits the API limit and starts to throttle requests)
for($i = 0; $i -le ($numberOfjobs - 1); $i++)
{
    # Wait for the jobs so that we don't crash the script or hit that many throttle errors
    Wait-ForJobs $maxNumberOfSimultaneousJobs
    
    # Amount of logs that should be skipped in the REST call. This is used to get the next logs each time we iterate and create the jobs
    $skipNumberOfLogs = $i * 100

    Write-Host "There are: $($numberOfLogsReturnedByQuery - $skipNumberOfLogs) logs left to fetch from MCAS! Spent $($timer.Elapsed.Hours)h $($timer.Elapsed.Minutes)m $($timer.Elapsed.Seconds)s getting $skipNumberOfLogs logs!" -ForegroundColor Yellow -BackgroundColor Black

    # Get the correct tokenNumber by removing the token count until it works
    # by doing this we are iterating through all the API keys and won't throttle the requests
    $tokenNumber = $i
    if(!$tokens[$tokenNumber])
    {
        do
        {
           $tokenNumber = $tokenNumber - $tokens.Count
        }
        until($tokens[$tokenNumber])
    }

    # Create jobs that collect 100 logs each since there is a limit on each REST API call.
    # This way we can speed up the process a lot
    Start-Job -Name "Get MCAS logs $($skipNumberOfLogs)-$($skipNumberOfLogs + 100)" -ArgumentList $skipNumberOfLogs, $collectLogsFromThisDateUnixFinal, $tokens[$tokenNumber], $portalUrl, $outputFilepath -ScriptBlock `
    {
        # Create variables from all the arguments
        $skipNumberOfLogs = $args[0]
        $collectLogsFromThisDateUnixFinal = $args[1]
        $token = $args[2]
        $portalUrl = $args[3]
        $outputFilepath = $args[4]
        
        do
        {
            $retryCall = $false
            try 
            {
                Write-Verbose "Attempting call to MCAS..."

                # The json body that is sent. We will always send a filter with (date: -gte $lastFetchedLogUnixTimestamp +1) which means that we can get the
                # last log date and send it in, adding 1 millisecond to the data in order to get everything that is newer than this log.
                # If you on the other hand want to get all logs, you can just send in a date whcih is earlier than the oldest log in the solution.
                if($collectLogsFromThisDate -eq "GetAll")
                {
                    # THis is a lot faster then if yo uadd filters to the API call
                    $jsonBody = "{`"skip`": 0,`"limit`": 100 }"
                }
                else
                {
                    $jsonBody = "{`"skip`": $skipNumberOfLogs,`"limit`": 100, `"filters`":{ `"date`": {`"gte`": $collectLogsFromThisDateUnixFinal } } }"
                }

                Write-Verbose "Final REST Call that will be run against the CAS solution:"
                Write-Verbose "Invoke-RestMethod -Method `"Post`""
                Write-Verbose "                  -Headers @{Authorization = `"Token $token`"}"
                Write-Verbose "                  -Uri `"https://$portalUrl/api/v1/activities/`""
                Write-Verbose "                  -ContentType `"application/json`""
                Write-Verbose "                  -UseBasicParsing"
                Write-Verbose "                  -Body $jsonBody"

                # And finally run the REST call against CAS, getting the logs
                $response = Invoke-RestMethod -Method "Post" `
                                              -Headers @{Authorization = "Token $token"} `
                                              -Uri "https://$portalUrl/api/v1/activities/" `
                                              -ContentType "application/json" `
                                              -UseBasicParsing `
                                              -Body $jsonBody `
                                              -Verbose
            }
            catch
            {
                if($_.Exception.Message -like "429")
                {
                    $retryCall = $true
                    Write-Warning "429 - Too many requests. The MCAS API throttling limit has been hit, the call will be retried in 3 second(s)..."
                    Write-Verbose "Sleeping for 3 seconds"
                    Start-Sleep -Seconds 3
                }
                elseif($_.Exception.Message -like "*500*")
                {
                    $retryCall = $true
                    Write-Warning "500 - Server Error..."
                    Write-Verbose "Sleeping for 3 seconds"
                    Start-Sleep -Seconds 3
                }
                elseif($_.Exception.Message -like "*504*")
                {
                    $retryCall = $true
                    Write-Warning "504 - Gateway Timeout. The call will be retried in 3 second(s)..."
                    Write-Verbose "Sleeping for 3 seconds"
                    Start-Sleep -Seconds 3
                }
                elseif($_.Exception.Message -like "*Request was throttled. Expected available in*")
                {
                    # Activate retry
                    $retryCall = $true

                    # Create json object from error output:
                    $json = '{\"detail\":\"Request was throttled. Expected available in 5.0 seconds.\"}'
                    $json = $json.Replace("\","")
                    $json = $json | ConvertFrom-Json

                    # Parse the time you need to wait until re-running the API Call
                    $waitTime = [Math]::Round(($json.detail).Split(" ")[($json.detail).Split(" ").Count - 2], 0)

                    # Wating the required time
                    Write-Warning "Request was throttled. The call will be retried in $waitTime second(s)..."
                    Write-Verbose "Sleeping for $waitTime seconds"
                    Start-Sleep -Seconds $waitTime
               }
                else
                {
                    throw $_
                }
            }
        }
        while ($retryCall)

        # Convert the fetched logs to a JSON Object
        do
        {
            $convertedToJson = $false
            try
            {
                # Sometimes this is already a object, therefore we check this before trying to convert it
                if($response.GetType().Name -ne "PSCustomObject")
                {
                    $response = $response | ConvertFrom-Json
                }
                else
                {
                    Write-Verbose "response were already a PSObject, didn't convert response."
                }
                $convertedToJson = $true
            }
            catch
            {
                if($_.Exception -like "*contains the duplicated keys*")
                {
                    # Remove duplicate keys since you won't be able to convert to Json
                    $errorMessage = $_.Exception
                    $duplicateKeyOne = $errorMessage.ToString().Split("'")[1]
                    $duplicateKeyTwo = $errorMessage.ToString().Split("'")[3]
                    $response = $response.Replace("$duplicateKeyOne","$duplicateKeyTwo")
                    Write-Verbose "Changed duplicate keys ($duplicateKeyOne => $duplicateKeyTwo) since it wasn't possible to convert the object to JSON"
                }
            }
        }
        Until($convertedToJson)

        # Get the timestamp from the last log ion the collection of logs that were fetched from the REST call
        $lastLogUnixTimestamp = $response.data.timestamp[0]

        # Convert the last log timestamp from the UNIX timestamp to a normal human readable time and date string
        $lastLogTimestamp = Get-Date((Get-Date -Year 1970 -Month 1 -Day 1 -Hour 1 -Minute 0 -Second 0 -Millisecond 0).ToUniversalTime().AddMilliseconds($response.data.timestamp[0])) -Format yyyyMMddHHmmssfff
        
        # Create the path and name of the file that will contain all the logs
        $newFilePathAndName = "$outputFilepath\CASLogs-$((Get-Date -Format yyyyMMddHHmmss))-Logs($($skipNumberOfLogs)-$($skipNumberOfLogs + 100))-Timestamp($lastLogTimestamp)-UnixTimestamp($lastLogUnixTimestamp).json"
        
        # Output all the logs to the file as JSON
        $response | ConvertTo-Json | Out-File -FilePath $newFilePathAndName

        Write-Verbose "Dumped all results to the file: `"$newFilePathAndName`""
    }
}

# Using the wait for jobs fucntion in order to collect all jobs before finalizing the script run - Sending 0 to wait for all jobs
Wait-ForJobs 0

# Get the log where we collected nr 0-100 since this is the newest log in in CAS. We need to note the time down so that we can start over from it at the next synchronizataion
$firstFile = (Get-ChildItem $outputFilepath | Where { $_.Name -like "*Logs(0-100)*" }).Name
$firstFileLastLogUnixTimestamp = $firstFile.Split("(").Split(")")[5]
$firstFileLastLogTimestamp = $firstFile.Split("(").Split(")")[3]
Write-Verbose "Creating new latestFetchedLogTimestamp.json file which is used by the script to tell which was the last log that it fetched from the solution. (New file: $latestFetchedLogTimestampFilepath\latestFetchedLogTimestamp.json)" 
"{`"latestFetchedLogTimestamp`": `"$firstFileLastLogTimestamp`" ,`"latestFetchedLogUnixTimestamp`": `"$firstFileLastLogUnixTimestamp`" }" | Out-File -FilePath "$latestFetchedLogTimestampFilepath\latestFetchedLogTimestamp.json" -Force

# Finally stop the timer
$timer.Stop()