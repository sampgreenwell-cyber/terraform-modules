<#
.SYNOPSIS
    Preflight check for the gmnupr lab: fails unless GitHub, Azure and (optionally)
    Kubernetes all point at the personal lab, never at work.

.DESCRIPTION
    Expected values come from terraform.tfvars next to this script (gitignored),
    so this public repo holds no tenant, subscription or account IDs.
    Run before any step that writes to GitHub, Azure or a cluster.

.EXAMPLE
    .\Test-LabTarget.ps1
    .\Test-LabTarget.ps1 -Kube
    .\Test-LabTarget.ps1 -Kube -Kubeconfig .\kubeconfig
#>
[CmdletBinding()]
param(
    [string]$VarsFile = (Join-Path $PSScriptRoot 'terraform.tfvars'),
    [switch]$Kube,
    [string]$Kubeconfig = (Join-Path $PSScriptRoot 'kubeconfig'),
    # Overrides, used to prove the check fails on a wrong target.
    [string]$ExpectSubscriptionId,
    [string]$ExpectKubeContext
)

$ErrorActionPreference = 'Stop'

function Read-TfVars([string]$path) {
    if (-not (Test-Path $path)) {
        throw "Lab values file not found: $path. Copy terraform.tfvars.example to terraform.tfvars and fill it in."
    }
    $vars = @{}
    foreach ($line in Get-Content $path) {
        if ($line -match '^\s*([a-z_]+)\s*=\s*"([^"]*)"') { $vars[$Matches[1]] = $Matches[2] }
        elseif ($line -match '^\s*([a-z_]+)\s*=\s*\[(.*)\]') {
            $vars[$Matches[1]] = @([regex]::Matches($Matches[2], '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
        }
    }
    # The work guard's values live here too, so this public repo names no employer.
    foreach ($k in 'tenant_id', 'subscription_id', 'github_owner', 'kube_context', 'work_github_orgs', 'work_kube_context_pattern') {
        if (-not $vars[$k]) { throw "Missing '$k' in $path (see terraform.tfvars.example)" }
    }
    return $vars
}

$vars = Read-TfVars $VarsFile
# Work GitHub orgs and Kubernetes context names that must never be targeted.
$workOrgs = @($vars.work_github_orgs)
$workContextPattern = $vars.work_kube_context_pattern
if ($ExpectSubscriptionId) { $vars.subscription_id = $ExpectSubscriptionId }
if ($ExpectKubeContext) { $vars.kube_context = $ExpectKubeContext }

$failures = New-Object System.Collections.Generic.List[string]
function Check([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) { Write-Host "PASS  $name - $detail" }
    else { Write-Host "FAIL  $name - $detail" -ForegroundColor Red; $failures.Add($name) }
}

# GitHub: the signed-in gh account must be the lab owner, and not a work org.
$ghUser = (& gh api user --jq .login 2>$null)
if ($ghUser) { $ghUser = $ghUser.Trim() }
Check 'GitHub account' ($ghUser -eq $vars.github_owner) "gh is '$ghUser', expected '$($vars.github_owner)'"
Check 'GitHub owner is not work' (-not ($workOrgs -contains $vars.github_owner)) "lab owner '$($vars.github_owner)'"

# Azure: the active az account must be the lab tenant and subscription.
$acct = (& az account show --query '{t:tenantId,s:id,n:name}' -o json 2>$null) | Out-String | ConvertFrom-Json
Check 'Azure tenant' ($acct -and $acct.t -eq $vars.tenant_id) "az tenant '$($acct.t)', expected lab tenant"
Check 'Azure subscription' ($acct -and $acct.s -eq $vars.subscription_id) "az subscription '$($acct.n)' ($($acct.s)), expected lab subscription"

# Kubernetes: only the lab context in the lab kubeconfig; never a work cluster.
if ($Kube) {
    if (-not (Test-Path $Kubeconfig)) {
        Check 'Kube config' $false "lab kubeconfig not found at $Kubeconfig"
    }
    else {
        $contexts = & kubectl config get-contexts -o name --kubeconfig $Kubeconfig 2>$null
        $current = (& kubectl config current-context --kubeconfig $Kubeconfig 2>$null)
        if ($current) { $current = $current.Trim() }
        Check 'Kube context' ($current -eq $vars.kube_context) "current '$current' in lab kubeconfig, expected '$($vars.kube_context)'"
        $work = @($contexts | Where-Object { $_ -match $workContextPattern })
        Check 'No work contexts' ($work.Count -eq 0) "work-looking contexts in lab kubeconfig: $($work -join ', ')"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "`nLab target check FAILED ($($failures -join ', ')). Do not continue." -ForegroundColor Red
    exit 1
}
Write-Host "`nLab target check passed."
exit 0
