# Input bindings are passed in via param block.
param($Timer)

# Specify the VMs that you want to stop. Modify or comment out below based on which VMs to check.
# Schema is '{"AutoShutdownStartup":  true,"StartTime": "7pm", "StopTime": "7am"}'
$TagName = "Cost"

# Stop on error
$ErrorActionPreference = 'stop'
try 
{
    Write-Information ("Getting all VMs in the subscription")
    $VMs = Get-AzVM

    # Check if VM has the specified tag on it and filter to those.
    If ($null -ne $TagName)
    {
        $VMs = $VMs | Where-Object {$_.Tags.Keys -eq $TagName}
    }

    # Stop the VM if it is running
    $ProcessedVMs = @()

    foreach ($VirtualMachine in $VMs)
    {
        # Check if the stat / stop is enabled and if the scheduled stop time hour is now
        $CostTag = ConvertFrom-Json $VirtualMachine.Tags.Cost
        if ($CostTag.AutoShutdownStartup -eq "true" -and (Get-Date $CostTag.StopTime).Hour -eq (Get-Date).Hour)
        {
            $VM = Get-AzVM -ResourceGroupName $VirtualMachine.ResourceGroupName -Name $VirtualMachine.Name -Status
            if ($VM.Statuses.Code[1] -eq 'PowerState/running')
            {
                Write-Information ("Stopping VM " + $VirtualMachine.Id)
                $ProcessedVMs += $VirtualMachine.Id
                Stop-AzVM -Id $VirtualMachine.Id -Force -AsJob | Write-Information
            }
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
