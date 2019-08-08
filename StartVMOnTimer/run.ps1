# Input bindings are passed in via param block.
param($Timer)

Wait-Debugger
# Specify the VMs that you want to start. Modify or comment out below based on which VMs to check.
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
