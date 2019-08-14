[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3a%2f%2fraw.githubusercontent.com%2feamonoreilly%2fAddTagToNewResources%2fmaster%2fazuredeploy.json) 
<a href="http://armviz.io/#/?load=https%3a%2f%2fraw.githubusercontent.com%2feamonoreilly%2fAddTagToNewResources%2fmaster%2fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

# Sample to start / stop VMs on a schedule based on a COST Tag. 

## Requirements
* You need to make sure the COST tag already exists in the subscription before deploying.
* You may need to redploy the template a second time due to the timing of the managed identity getting created in Azure AD. Running a second time should resovle this issue.
* Any VM created in the same resource group as this function app will automatically have the COST tag added and will shutdown / restart based on the time set

