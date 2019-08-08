param($eventGridEvent, $TriggerMetadata)
$ErrorActionPreference = 'stop'

# Write out data to help in troubleshooting if needed.
$eventGridEvent.data | Out-String -Width 300 | Write-Host

$ChannelURL = $Env:TeamsWebhook
if (-not $ChannelURL)
{
    Write-Warning ("You need to add the Teams webhook url to the function environment app setting (TeamsWebhook) as it is empty.")
}

$Data = $eventGridEvent.data

if($Data.operationName -match "Microsoft.Compute/virtualMachines/write" -and $Data.status -match "Succeeded")
{ 
    # Set tags names
    $TagName = "Cost"
    $TagValue = '{"AutoShutdownStartup":  true,"StartTime": "7pm", "StopTime": "7am"}'

    # Get resource group and vm name
    $Resources = $Data.resourceUri.Split('/')
    $VMResourceGroup = $Resources[4]
    $VMName = $Resources[8]

    # Check if tag name exists in subscription and error if Cost tag does not exist.
    $TagExists = Get-AzTag -Name $TagName -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($TagExists))
    {
        Write-Error("You need to create a tag called 'Cost' on any resource in the subscription before enabling this function")
    }

    # Check if this VM already has the tag set.
    $VM = Get-AzVM -ResourceGroupName $VMResourceGroup -Name $VMName
    if (!($VM.Tags.ContainsKey($TagName)))
    {
        $VM.Tags.Add($TagName,$TagValue)

        # Add Cost tag to VM
        Update-AzVM -ResourceGroupName $VMResourceGroup -VM $VM -Tag $VM.Tags | Write-Verbose

        #Post to teams if the channel webhook is present.   
        if (!([string]::IsNullOrEmpty($ChannelURL)))
        {
            $TargetURL = "https://portal.azure.com/#resource" + $Data.resourceUri + "/overview"   
            
            $Body = ConvertTo-Json -Depth 4 @{
            title = 'Azure VM Creation Notification' 
            text = 'A new Azure VM is available'
            sections = @(
                @{
                activityTitle = 'Azure VM'
                activitySubtitle = 'VM ' + $VM.Name + ' has been set up for automatic shutdown at 7pm and start up at 8am'
                activityText = 'VM was created in resource group ' + $VM.ResourceGroupName + '. Set Cost Tag on VM to false to turn off'
                activityImage = 'https://106c4.wpc.azureedge.net/80106C4/Gallery-Prod/cdn/2015-02-24/prod20161101-microsoft-windowsazure-gallery/Microsoft.FunctionApp.8.1.1/Icons/Large.png'
                }
            )
            potentialAction = @(@{
                '@context' = 'http://schema.org'
                '@type' = 'ViewAction'
                name = 'Click here to manage the VM'
                target = @($TargetURL)
                })
            }

            # Call Teams webhook
            Invoke-RestMethod -Method "Post" -Uri $ChannelURL -Body $Body | Write-Verbose
        }
    }
}
else
{
    Write-Error "Could not find VM write event"
}

