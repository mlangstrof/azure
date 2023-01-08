
# Parameters
$thresholdInUsd = 5
$deleteResources = $true
$subscriptionId = ""
$listOfExcludedResourceTypes = @("Microsoft.Storage/storageAccounts")

Set-AzContext -SubscriptionId $subscriptionId

# Collect list of all resources that are deployed in the subscription
$allBillableResources = ((Get-AzConsumptionUsageDetail).InstanceId | Sort-Object | Get-Unique)


# Loop through all remaining resources and shutdown or delete resources
foreach ($resourceId in $allBillableResources){
	# Get resource cost for cost period and check if it is under the defined threshold
	$resourceCostForPeriod =  Get-AzConsumptionUsageDetail -IncludeMeterDetails -InstanceName $resourceId
	$resourceCostAggregated = 0
	foreach($entry in $resourceCostForPeriod){$resourceCostAggregated += $t.pretaxcost}  
	
	# Get supported actions for resource type
	$resourceType = (Get-AzResource -resourceId $resourceId).resourceType 
	$supportedOperations = Get-AzProviderOperation $resourceType/*
	
	if(![string]::IsNullOrEmpty($supportedOperations.operation -match "powerOff")){
			Write-Host "Performing powerOff for resource $resourceId"
			Invoke-AzResourceAction -Action "powerOff" -ResourceId $resourceId
	} elseif(![string]::IsNullOrEmpty($supportedOperations.operation -match "stop")){
			Write-Host "Performing stop for resource $resourceId"
			Invoke-AzResourceAction -Action "stop" -ResourceId $resourceId
	} elseif(![string]::IsNullOrEmpty($supportedOperations.operation -match "pause")){
			Write-Host "Performing pause for resource $resourceId"
			Invoke-AzResourceAction -Action "pause" -ResourceId $resourceId
	} else {
		if ($resourceCostAggregated -gt $thresholdInUsd){
		$resource = Get-AzResource -ResourceId $resourceId
		Write-Host "Exporting template for resource before deleting"
		Export-AzResourceGroup -ResourceGroupName $resource.resourceGroupName -Resource $resource.ResourceId
		# Save to gallery (or storage account)?
		Write-Host "Deleting resource $resourceId"
		if(!listOfExcludedResourceTypes -contains $resource.resourceType)
			Remove-AzResource -ResourceId $resourceId
		} else {
			Write-Host "Costs for resource $resourceId is lower than the defined threshold $thresholdInUsd, therefore not deleting the resource"
		}
	} 
}
