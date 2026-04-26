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

Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
$systemTempPath = [System.IO.Path]::GetTempPath()
if ($env:TG_DOWNLOAD_DIR) {
    $tempPath = $env:TG_DOWNLOAD_DIR
}
else {
    $tempPath = $systemTempPath
}
$out_path = [System.IO.Path]::Combine($tempPath, "${uuidv5("dns", basename(get_original_terragrunt_dir()))}")

Write-Output "DEBUG: out_path: $out_path"

# backend storage account details
if ($env:TG_CTX_COMMAND -eq "plan") {
    # "plan" like command - need to parse the tfplan file and build an apply-like output
    $tfPlanOutput = (terraform show -no-color -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json)

    # actor_identity
    $tfOutputAIPlanned  =  $tfPlanOutput.planned_values.outputs.actor_identity.value
    $tfOutputAIAfter = $tfPlanOutput.output_changes.actor_identity.after
    $tfOutputAIAfterUnknown =$tfPlanOutput.output_changes.actor_identity.after_unknown
    $tfOutputAIMerged = Merge-Objects -Object1 $tfOutputAIAfterUnknown -Object2 $tfOutputAIAfter
    $tfOutputAIMerged = Merge-Objects -Object1 $tfOutputAIMerged -Object2 $tfOutputAIPlanned

    # actor_network_information
    $tfOutputANPlanned  =  $tfPlanOutput.planned_values.outputs.actor_network_information.value
    $tfOutputANAfter = $tfPlanOutput.output_changes.actor_network_information.after
    $tfOutputANAfterUnknown =$tfPlanOutput.output_changes.actor_network_information.after_unknown
    $tfOutputANMerged = Merge-Objects -Object1 $tfOutputANAfterUnknown -Object2 $tfOutputANAfter
    $tfOutputANMerged = Merge-Objects -Object1 $tfOutputANMerged -Object2 $tfOutputANPlanned
    
    # backend_resource_group
    $tfOutputBRGPlanned  =  $tfPlanOutput.planned_values.outputs.backend_resource_group.value
    $tfOutputBRGAfter = $tfPlanOutput.output_changes.backend_resource_group.after
    $tfOutputBRGAfterUnknown =$tfPlanOutput.output_changes.backend_resource_group.after_unknown
    $tfOutputBRGMerged = Merge-Objects -Object1 $tfOutputBRGAfterUnknown -Object2 $tfOutputBRGAfter
    $tfOutputBRGMerged = Merge-Objects -Object1 $tfOutputBRGMerged -Object2 $tfOutputBRGPlanned

    # backend_storage_accounts
    $tfOutputBSPlanned  =  $tfPlanOutput.planned_values.outputs.backend_storage_accounts.value
    $tfOutputBSAfter = $tfPlanOutput.output_changes.backend_storage_accounts.after
    $tfOutputBSAfterUnknown =$tfPlanOutput.output_changes.backend_storage_accounts.after_unknown
    $tfOutputBSMerged = Merge-Objects -Object1 $tfOutputBSAfterUnknown -Object2 $tfOutputBSAfter
    $tfOutputBSMerged = Merge-Objects -Object1 $tfOutputBSMerged -Object2 $tfOutputBSPlanned

    $terraform_output = @{
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
elseif ($env:TG_CTX_COMMAND -eq "apply") {
    $terraform_output = terraform output -json | ConvertFrom-Json
}

$filePath = Join-Path $out_path "terraform_output.json"
$terraform_output_json = @{
    "actor_identity"            = $terraform_output.actor_identity.value
    "actor_network_information" = $terraform_output.actor_network_information.value
    "backend_storage_accounts"  = $terraform_output.backend_storage_accounts.value
} | ConvertTo-Json -Depth 5

Write-Output "    Writing $filePath with module's output"
Set-Content -Path $filePath -Value $terraform_output_json -Encoding UTF8 -Force