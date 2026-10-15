# Shared helpers for the gmnupr lab scripts. Dot-source: . "$PSScriptRoot\LabCommon.ps1"
# No lab values live here; they come from terraform.tfvars (gitignored).

$script:LabRoot = $PSScriptRoot
$script:LabTerraformDir = Join-Path $PSScriptRoot 'terraform'
$script:LabVarsFile = Join-Path $PSScriptRoot 'terraform.tfvars'
$script:LabKubeconfig = Join-Path $PSScriptRoot 'kubeconfig'

function Read-LabVars {
    if (-not (Test-Path $script:LabVarsFile)) {
        throw "Lab values file not found: $($script:LabVarsFile). Copy terraform.tfvars.example to terraform.tfvars and fill it in."
    }
    $vars = @{}
    foreach ($line in Get-Content $script:LabVarsFile) {
        if ($line -match '^\s*([a-z_]+)\s*=\s*"([^"]*)"') { $vars[$Matches[1]] = $Matches[2] }
    }
    return $vars
}

function Invoke-LabNative {
    # Runs a native command and throws if it fails, so scripts stop at the first error.
    # Judges success by exit code only: tools like openssl write progress to stderr, which
    # Windows PowerShell would otherwise turn into a terminating error under 'Stop'.
    param([Parameter(Mandatory)][string]$File, [string[]]$Arguments = @())
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $File @Arguments 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $saved }
    if ($LASTEXITCODE -ne 0) { throw "$File $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
}

function Assert-LabTarget {
    param([switch]$Kube)
    $checkArgs = @{}
    if ($Kube) { $checkArgs['Kube'] = $true }
    & (Join-Path $script:LabRoot 'Test-LabTarget.ps1') @checkArgs
    if ($LASTEXITCODE -ne 0) { throw 'Lab target check failed; stopping (Work Isolation rule).' }
}

function Get-LabOutputs {
    $json = & terraform "-chdir=$($script:LabTerraformDir)" output -json
    if ($LASTEXITCODE -ne 0 -or -not $json) { throw 'No Terraform outputs; has the lab been applied?' }
    $raw = ($json | Out-String) | ConvertFrom-Json
    $out = @{}
    foreach ($p in $raw.PSObject.Properties) { $out[$p.Name] = $p.Value.value }
    return $out
}

function Get-LabOpenSsl {
    $cmd = Get-Command openssl -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @("$env:ProgramFiles\Git\usr\bin\openssl.exe", "$env:ProgramFiles\Git\mingw64\bin\openssl.exe")) {
        if (Test-Path $p) { return $p }
    }
    throw 'openssl not found (it ships with Git for Windows).'
}

function Invoke-LabKubectl {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $vars = Read-LabVars
    Invoke-LabNative kubectl (@('--kubeconfig', $script:LabKubeconfig, '--context', $vars.kube_context) + $Arguments)
}
