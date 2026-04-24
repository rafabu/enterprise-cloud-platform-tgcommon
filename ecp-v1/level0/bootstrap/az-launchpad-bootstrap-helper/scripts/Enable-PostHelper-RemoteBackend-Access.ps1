function Merge-Objects {
    param (
        [object]$Object1,
        [object]$Object2
    )
    $merged = [ordered]@{}
    foreach ($prop in $Object1.PSObject.Properties) {
        $merged[$prop.Name] = $prop.Value
    }
    foreach ($prop in $Object2.PSObject.Properties) {
        $merged[$prop.Name] = $prop.Value
    }
    return [PSCustomObject]$merged
}

function Set-StorageAccountAccess {
    param(
        [string]$ecpLevel,
        [string]$subscriptionId,
        [bool]$resourceExists,
        [string]$accountName,
        [string]$localIp,
        [string]$publicIp,
        [string]$ipInRange,
        [bool]$blobPeResolution,
        [bool]$ecpIdentity,
        [string]$displayName,
        [string]$objectId,
        [string]$principalType,
        [string]$roleName
    )

    # if not running from within launchpad network, access to backend will be blocked by storage account firewall
    #     temporarily(!) open up access for the duration of this run
    #     plus RBAC permissions if not using ECP Identity
    if ($true -eq $resourceExists) {
        Write-Output "INFO: $ecpLevel - Storage Account $accountName exists; querying"
        $sa = az storage account show `
            --subscription $subscriptionId `
            --name $accountName `
            -o json | ConvertFrom-Json

        Write-Output "##### $ecpLevel - network access #####"
        if ($true -eq $resourceExists -and ("false" -eq $ipInRange -or $false -eq $blobPeResolution) -and $null -ne $publicIp) {
            Write-Output "INFO: $ecpLevel - Local IP is $localIp is not in launchpad range  OR"
            Write-Output " - private endpoint does not exist"
            Write-Output " - private endpoint resolution failed"
            Write-Output "INFO: $ecpLevel - checking if access to storage account $accountName via public IP $publicIp is allowed..."
            if ($sa.publicNetworkAccess -ne "Enabled") {
                Write-Output "     Public network access is $($sa.publicNetworkAccess). Enabling..."
                az storage account update `
                    --subscription $subscriptionId `
                    --name $accountName `
                    --public-network-access Enabled | Out-Null
            }
            else {
                Write-Output "     public network access is already Enabled. No change needed."
            }
            # Get current allowed IPs
            $rules = az storage account network-rule list `
                --subscription $subscriptionId `
                --account-name $accountName `
                --query "ipRules[].ipAddressOrRange" `
                -o tsv
            if ($rules -contains $publicIp) {
                Write-Output "     IP $publicIp is already allowed per network-rule of storage account $accountName. No change needed."
            }
            else {
                Write-Output "     IP $publicIp is being added to network-rule of storage account $accountName..."
                az storage account network-rule add `
                    --subscription $subscriptionId `
                    --account-name $accountName `
                    --ip-address $publicIp | Out-Null
                Write-Output "     added..."
                $waitNeeded = $true
            }
        }
        elseif ("true" -eq $ipInRange) {
            Write-Output "INFO: $ecpLevel - Private IP $localIp is in launchpad vnet range; no need to add public IP to Storage Account $accountName."
        }
        elseif ($null -eq $publicIp) {
            Write-Output "WARNING: $ecpLevel - No public IP available; cannot add to Storage Account $accountName."
        }
        elseif ($false -eq $resourceExists) {
            Write-Output "WARNING: $ecpLevel - Storage Account $accountName does not exist yet; cannot configure network access."
        }
        Write-Output ""

        Write-Output "##### $ecpLevel - Blob Access #####"
        if ($false -eq $ecpIdentity) {
            Write-Output "INFO: identity $displayName isn't an ECP Identity; checking its '$roleName' assignment on $accountName."
            $assignment = az role assignment list `
                --subscription $subscriptionId `
                --assignee-object-id $objectId `
                --role "$roleName" `
                --scope $sa.id `
                -o tsv

            if ($assignment) {
                Write-Host "    identity $displayName already has role '$roleName' on $accountName (terraform command: '$env:TG_CTX_COMMAND')"
            }
            else {
                Write-Host "     assigning role '$roleName' to $displayName on $accountName..."
                az role assignment create `
                    --subscription $subscriptionId `
                    --description "ECP_BOOTSTRAP_HELPER" `
                    --assignee-object-id $objectId `
                    --assignee-principal-type $principalType `
                    --role "$roleName" `
                    --scope $sa.id | Out-Null
                Write-Output "     added..."
                $waitNeeded = $true
            }
        }
        else {
            Write-Output "INFO: $ecpLevel - Running with ECP Identity $displayName; assuming it has sufficient access. No change needed."
        }
    }
    else {
        Write-Output "INFO: $ecpLevel - Storage Account $accountName does not exist yet; cannot configure access. Will have to run on local terraform backend for now."
    }
    Write-Output ""
    if ($waitNeeded) {
        Write-Output "INFO: $ecpLevel - Sleep 60 seconds for RBAC and/or SA port rule changes to propagate on $accountName"
        Start-Sleep -Seconds 60
    }

}


Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

$tgWriteCommands = @(
    "apply",
    "destroy",
    "force-unlock",
    "import",
    "refresh",
    "taint",
    "untaint"
)

if ($tgWriteCommands -inotcontains $env:TG_CTX_COMMAND) {
    # "plan" like command - need to parse the tfplan file and build an apply-like output
    $tfPlanOutput = (terraform show -no-color -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json)

    # actor_identity
    $tfOutputAIPlanned = $tfPlanOutput.planned_values.outputs.actor_identity.value
    $tfOutputAIAfter = $tfPlanOutput.output_changes.actor_identity.after
    $tfOutputAIAfterUnknown = $tfPlanOutput.output_changes.actor_identity.after_unknown
    $tfOutputAIMerged = Merge-Objects -Object1 $tfOutputAIAfterUnknown -Object2 $tfOutputAIAfter
    $tfOutputAIMerged = Merge-Objects -Object1 $tfOutputAIMerged -Object2 $tfOutputAIPlanned

    # actor_network_information
    $tfOutputANPlanned = $tfPlanOutput.planned_values.outputs.actor_network_information.value
    $tfOutputANAfter = $tfPlanOutput.output_changes.actor_network_information.after
    $tfOutputANAfterUnknown = $tfPlanOutput.output_changes.actor_network_information.after_unknown
    $tfOutputANMerged = Merge-Objects -Object1 $tfOutputANAfterUnknown -Object2 $tfOutputANAfter
    $tfOutputANMerged = Merge-Objects -Object1 $tfOutputANMerged -Object2 $tfOutputANPlanned
    
    # backend_resource_group
    $tfOutputBRGPlanned = $tfPlanOutput.planned_values.outputs.backend_resource_group.value
    $tfOutputBRGAfter = $tfPlanOutput.output_changes.backend_resource_group.after
    $tfOutputBRGAfterUnknown = $tfPlanOutput.output_changes.backend_resource_group.after_unknown
    $tfOutputBRGMerged = Merge-Objects -Object1 $tfOutputBRGAfterUnknown -Object2 $tfOutputBRGAfter
    $tfOutputBRGMerged = Merge-Objects -Object1 $tfOutputBRGMerged -Object2 $tfOutputBRGPlanned

    # backend_storage_accounts
    $tfOutputBSPlanned = $tfPlanOutput.planned_values.outputs.backend_storage_accounts.value
    $tfOutputBSAfter = $tfPlanOutput.output_changes.backend_storage_accounts.after
    $tfOutputBSAfterUnknown = $tfPlanOutput.output_changes.backend_storage_accounts.after_unknown
    $tfOutputBSMerged = Merge-Objects -Object1 $tfOutputBSAfterUnknown -Object2 $tfOutputBSAfter
    $tfOutputBSMerged = Merge-Objects -Object1 $tfOutputBSMerged -Object2 $tfOutputBSPlanned

    $tfOutput = @{
        "actor_identity"            = @{
            "value" = $tfOutputAIMerged
        };
        "actor_network_information" = @{
            "value" = $tfOutputANMerged
        };
        "backend_resource_group"    = @{
            "value" = $tfOutputBRGMerged
        };
        "backend_storage_accounts"  = @{
            "value" = $tfOutputBSMerged
        }
    }
}
else {
    # "apply" like command - write access is required
    $tfOutput = terraform output -json | ConvertFrom-Json
}

$ipInRange = if ($tfOutput.actor_network_information.value.is_local_ip_within_ecp_launchpad -eq "true") { "true" } else { "false" }
$localIp = $tfOutput.actor_network_information.value.local_ip
$publicIp = $tfOutput.actor_network_information.value.public_ip

$roleName = "Storage Blob Data Contributor"

$objectId = $tfOutput.actor_identity.value.object_id
$displayName = $tfOutput.actor_identity.value.display_name
$ecpIdentity = if ("true" -eq $tfOutput.actor_identity.value.is_ecp_launchpad_identity -eq $true) { $true } else { $false }
$principalType = if ("user" -eq $tfOutput.actor_identity.value.type) { "User" } else { "ServicePrincipal" }


#l0
$resourceExists = if ($tfOutput.backend_storage_accounts.value.l0.ecp_resource_exists -eq "true") { $true } else { $false }
$subscriptionId = $tfOutput.backend_storage_accounts.value.l0.subscription_id
$accountName = $tfOutput.backend_storage_accounts.value.l0.name
$blobPeResolution = $tfOutput.backend_storage_accounts.value.l0.ecp_terraform_backend_private_endpoint_resolution_valid

#l1
$resourceExistsl1 = if ($tfOutput.backend_storage_accounts.value.l1.ecp_resource_exists -eq "true") { $true } else { $false }
$subscriptionIdl1 = $tfOutput.backend_storage_accounts.value.l1.subscription_id
$accountNamel1 = $tfOutput.backend_storage_accounts.value.l1.name
$blobPeResolutionl1 = $tfOutput.backend_storage_accounts.value.l1.ecp_terraform_backend_private_endpoint_resolution_valid

#l2
$resourceExistsl2 = if ($tfOutput.backend_storage_accounts.value.l2.ecp_resource_exists -eq "true") { $true } else { $false }
$subscriptionIdl2 = $tfOutput.backend_storage_accounts.value.l2.subscription_id
$accountNamel2 = $tfOutput.backend_storage_accounts.value.l2.name
$blobPeResolutionl2 = $tfOutput.backend_storage_accounts.value.l2.ecp_terraform_backend_private_endpoint_resolution_valid

# ForEach-Object -Parallel 
$levels = @(
    @{ Level = "l0"; ResourceExists = $resourceExists; SubscriptionId = $subscriptionId; AccountName = $accountName; BlobPeResolution = $blobPeResolution; }
    @{ Level = "l1"; ResourceExists = $resourceExistsl1; SubscriptionId = $subscriptionIdl1; AccountName = $accountNamel1; BlobPeResolution = $blobPeResolutionl1; }
    @{ Level = "l2"; ResourceExists = $resourceExistsl2; SubscriptionId = $subscriptionIdl2; AccountName = $accountNamel2; BlobPeResolution = $blobPeResolutionl2; }
)

# Capture function body and shared vars for use inside parallel runspaces
$funcDef = ${function:Set-StorageAccountAccess}.ToString()
$sharedLocalIp = $localIp
$sharedPublicIp = $publicIp
$sharedIpInRange = $ipInRange
$sharedEcpIdentity = $ecpIdentity
$sharedDisplayName = $displayName
$sharedObjectId = $objectId
$sharedPrincipalType = $principalType
$sharedRoleName = $roleName

$levels | ForEach-Object -Parallel {
    # Re-define function in this runspace
    ${function:Set-StorageAccountAccess} = $using:funcDef

    Set-StorageAccountAccess `
        -ecpLevel        $_.Level `
        -subscriptionId  $_.SubscriptionId `
        -resourceExists  $_.ResourceExists `
        -accountName     $_.AccountName `
        -localIp         $using:sharedLocalIp `
        -publicIp        $using:sharedPublicIp `
        -ipInRange       $using:sharedIpInRange `
        -blobPeResolution $_.BlobPeResolution `
        -ecpIdentity     $using:sharedEcpIdentity `
        -displayName     $using:sharedDisplayName `
        -objectId        $using:sharedObjectId `
        -principalType   $using:sharedPrincipalType `
        -roleName        $using:sharedRoleName
}
