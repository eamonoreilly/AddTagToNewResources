# Input bindings are passed in via param block.
param($Timer)

# Specify the VMs that you want to start. Modify or comment out below based on which VMs to check.
# Schema is '{"AutoShutdownStartup":  true,"StartTime": "7am", "StopTime": "7pm"}'
$TagName = "Cost"

# Stop on error
$ErrorActionPreference = 'stop'

# If you are using the durable sample on https://github.com/eamonoreilly/VMStartedDurable you should update
# the below code with the APIM api created for it by adding a API_URL app setting for the url
function GetStartTime {
    param (
        $VMId
    )
    if ($Env:API_Key)
    {
        $Headers = @{}
        $Headers.Add("Ocp-Apim-Subscription-Key","$Env:API_Key")
        $URL = $Env:API_URL
        try {
            $VMEntity = Invoke-RestMethod ("$URL" + "?" + "VMId=$VMId") -Headers $Headers
            $VMEntity.entityState.hour
        }
        catch {
            return
        }
    }
    else {
        Write-Warning ("API_Key app setting is not set. You need to set this and call the API to get the calculated start time")
    }
}

try 
{
    Write-Information ("Getting all VMs in the subscription")
    $VMs = Get-AzVM

    # Check if VM has the specified tag on it and filter to those.
    If ($null -ne $TagName)
    {
        $VMs = $VMs | Where-Object {$_.Tags.Keys -eq $TagName}
    }

    # Start the VM if it is deallocated
    $ProcessedVMs = @()
    foreach ($VirtualMachine in $VMs)
    {
        # Check if the stat / stop is enabled and if the scheduled start time hour is now
        $CostTag = ConvertFrom-Json $VirtualMachine.Tags.Cost
        if ($CostTag.AutoShutdownStartup -eq "true" -and (Get-Date $CostTag.StartTime).Hour -eq (Get-Date).Hour)
        {
            $VM = Get-AzVM -ResourceGroupName $VirtualMachine.ResourceGroupName -Name $VirtualMachine.Name -Status
            if ($VM.Statuses.Code[1] -eq 'PowerState/deallocated')
            {
                Write-Information ("Starting VM " + $VirtualMachine.Id)
                $ProcessedVMs += $VirtualMachine.Id
                Start-AzVM -Id $VirtualMachine.Id -AsJob | Write-Information
            }
        }
        # Update start time if it newer than current time (Sample using https://github.com/eamonoreilly/VMStartedDurable)
        $VMStartTime = GetStartTime -VMId $VirtualMachine.Id
        Write-Output $VMStartTime
        if ((![string]::IsNullOrEmpty($VMStartTime)) -and ($VMStartTime -lt (Get-Date $CostTag.StartTime).Hour))
        {
            if ($VMStartTime -gt 12)
            {
                $VirtualMachine.Tags.Cost = '{"AutoShutdownStartup": true, "StartTime": "' + ($VMStartTime -12) + 'pm", "StopTime": "7pm"}'
            }
            else {
                $VirtualMachine.Tags.Cost = '{"AutoShutdownStartup": true, "StartTime": "' + $VMStartTime + 'am", "StopTime": "7pm"}'
            }
            Update-AzVM -ResourceGroupName $VirtualMachine.ResourceGroupName -VM $VirtualMachine -Tag $VirtualMachine.Tags | Write-Verbose
        }
    }
    # Sleep here a few seconds to make sure that the command gets processed before the script ends
    if ($ProcessedVMs.Count -gt 0)
    {
        Start-Sleep 30
    } 
}
catch
{
    throw $_.Exception.Message
}
