param(
    [string]$unitName
)

Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
$systemTempPath = [System.IO.Path]::GetTempPath()
if ($env:TG_DOWNLOAD_DIR) {
    $tempPath = $env:TG_DOWNLOAD_DIR
}
else {
    $tempPath = $systemTempPath
}
$out_path = [System.IO.Path]::Combine($tempPath, $unitName)
if (-not (Test-Path -Path $out_path -PathType Container)) {
    New-Item -ItemType Directory -Path $out_path -Force | Out-Null
}