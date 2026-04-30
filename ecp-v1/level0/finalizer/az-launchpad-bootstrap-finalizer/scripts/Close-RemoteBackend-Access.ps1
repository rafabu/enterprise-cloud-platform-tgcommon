param(
    
    [string]$ipInRangeString,
    [string]$publicIp,
    [string]$objectId,
    [string]$ecpIdentityString,
    [string]$resourceExistsString,
    [string]$resourceExistsStringl1,
    [string]$resourceExistsStringl2,
    [string]$subscriptionId,
    [string]$subscriptionIdl1,
    [string]$subscriptionIdl2,
    [string]$accountName,
    [string]$accountNamel1,
    [string]$accountNamel2
)

function Remove-StorageAccountAccess {
    param(
        [string]$ecpLevel,
        [bool]$resourceExists,
        [bool]$ipInRange,
        [string]$publicIp,
        [string]$subscriptionId,
        [string]$accountName,
        [bool]$ecpIdentity,
        [string]$objectId
    )

    if ($true -eq $resourceExists) {
        Write-Output "INFO: $ecpLevel - Storage Account should exist; querying"
        $sa = az storage account show `
            --subscription $subscriptionId `
            --name $accountName `
            -o json | ConvertFrom-Json
        Write-Output ""

        Write-Output "##### network access #####"
        if ($true -eq $resourceExists -and $false -eq $ipInRange -and $publicIp -ne $null) {
            Write-Output "INFO: $ecpLevel - Checking Storage Account $accountName for public IP $publicIp access..."
            # Get current allowed IPs
            $rules = az storage account network-rule list `
                --subscription $subscriptionId `
                --account-name $accountName `
                --query "ipRules[].ipAddressOrRange" `
                -o tsv
            if ($rules -contains $publicIp) {
                Write-Output "     Remove $publicIp from network-rule of storage account $accountName..."
                az storage account network-rule remove `
                    --subscription $subscriptionId `
                    --account-name $accountName `
                    --ip-address $publicIp | Out-Null
                Write-Output "     removed..."
            }
            else {
                Write-Output "    $publicIp not in network-rule of storage account $accountName."
            }
            if ($sa.publicNetworkAccess -eq "Enabled") {
                Write-Output "     Disable public network access again..."
                az storage account update `
                    --subscription $subscriptionId `
                    --name $accountName `
                    --public-network-access Disabled | Out-Null
            }
            else {
                Write-Output "     Public network access already disabled."
            }
        }
        elseif ($true -eq $ipInRange) {
            Write-Output "INFO: $ecpLevel - Private IP is in launchpad vnet range"
            Write-Output "INFO: $ecpLevel -     no need to remove network rule from Storage Account $accountName."
        }
        elseif ($publicIp -eq $null) {
            Write-Output "WARNING: $ecpLevel - No public IP available; cannot configure Storage Account $accountName."
        }
        elseif ($false -eq $resourceExists) {
            Write-Output "WARNING: $ecpLevel - Storage Account $accountName does not exist yet.."
        }
        Write-Output ""

        Write-Output "##### Blob Access #####"
        if ($false -eq $ecpIdentity) {
            Write-Output "INFO: $ecpLevel - No ECP Identity provided; checking role assignment."
            $assignments = az role assignment list `
                --subscription $subscriptionId `
                --assignee-object-id $objectId `
                --scope $sa.id `
                -o JSON | ConvertFrom-Json | Where-Object { $_.description -eq "ECP_BOOTSTRAP_HELPER" }

            foreach ($assignment in $assignments) {
                Write-Host "    Removing $objectId access with role '$assignment.roleDefinitionId' on $accountName"
                az role assignment delete `
                    --subscription $subscriptionId ` `
                    --ids $assignment.id | Out-Null
            }
            if ($assignments.Count -eq 0) {
                Write-Output "INFO:    No RBAC role assignments with description 'ECP_BOOTSTRAP_HELPER' found for $objectId on $accountName."
            }
        }
    }
    else {
        Write-Output "INFO: $ecpLevel - Storage Account does not exist yet; cannot configure access."
    }
}

Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
# if not running from within launchpad network, access to backend will be blocked by storage account firewall
#     always(!) need to remove access again --> run_on_error = true
# remove temporary fw and RBAC again
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

$ipInRange = if ("true" -eq $ipInRangeString) { $true } else { $false }
$ecpIdentity = if ("true" -eq $ecpIdentityString) { $true } else { $false }

# ForEach-Object -Parallel 
$levels = @(
    @{
        Level          = "l0";
        ResourceExists = if ("true" -eq $resourceExistsString) { $true } else { $false };
        SubscriptionId = $subscriptionId;
        AccountName    = $accountName
    }
    @{
        Level          = "l1";
        ResourceExists = if ("true" -eq $resourceExistsStringl1) { $true } else { $false };
        SubscriptionId = $subscriptionIdl1;
        AccountName    = $accountNamel1
    }
    @{
        Level          = "l2";
        ResourceExists = if ("true" -eq $resourceExistsStringl2) { $true } else { $false };
        SubscriptionId = $subscriptionIdl2;
        AccountName    = $accountNamel2
    }
)

# Capture function body and shared vars for use inside parallel runspaces
$funcDef = ${function:Remove-StorageAccountAccess}.ToString()
$sharedIpInRange = $ipInRange
$sharedPublicIp = $publicIp
$sharedEcpIdentity = $ecpIdentity
$sharedObjectId = $objectId

$levels | ForEach-Object -Parallel {
    # Re-define function in this runspace
    ${function:Remove-StorageAccountAccess} = $using:funcDef

    Remove-StorageAccountAccess `
        -ecpLevel        $_.Level `
        -subscriptionId  $_.SubscriptionId `
        -resourceExists  $_.ResourceExists `
        -accountName     $_.AccountName `
        -publicIp        $using:sharedPublicIp `
        -ipInRange       $using:sharedIpInRange `
        -ecpIdentity     $using:sharedEcpIdentity `
        -objectId        $using:sharedObjectId
}

Write-Output ""