<#
.SYNOPSIS
    Tears the gmnupr lab down: Azure resources, lab pull requests, throwaway service repos,
    optionally the vwstate-lab repo, and local lab files. -PlanOnly shows everything first.

.DESCRIPTION
    Stages (-Scope; default Azure, PullRequests, ServiceRepos, Local):
      Azure         terraform destroy of rg-gmnupr-lab (AKS, ACR, identities and their
                    federated credentials, budget), then checks the resource group is gone.
      PullRequests  closes open onboarding PRs (head branch onboard/*) in vwstate-lab and
                    deletes their branches.
      ServiceRepos  deletes the service repos the template created: every
                    kubernetes/versions/<Repo>.yaml in vwstate-lab whose <Repo> exists under the
                    lab GitHub account (sanitized work names are skipped: they don't exist there).
      VwstateLab    deletes the vwstate-lab repo itself. Never in the default scope.
      Local         deletes the lab kubeconfig and the dispatch token file.
    Deleting repos needs the gh token's delete_repo scope: gh auth refresh -h github.com -s delete_repo
    Not done here (no API for it): revoke the fine-grained dispatch token in GitHub settings,
    and unregister the service components in Backstage (their repos are gone).

.EXAMPLE
    .\Remove-Lab.ps1 -PlanOnly                                  # show everything, change nothing
    .\Remove-Lab.ps1 -Yes                                       # default scope
    .\Remove-Lab.ps1 -Yes -Scope Azure                          # Azure only (stop paying)
    .\Remove-Lab.ps1 -Yes -Scope PullRequests,ServiceRepos,VwstateLab
#>
[CmdletBinding()]
param(
    [switch]$PlanOnly,
    [switch]$Yes,
    [ValidateSet('Azure', 'PullRequests', 'ServiceRepos', 'VwstateLab', 'Local')]
    [string[]]$Scope = @('Azure', 'PullRequests', 'ServiceRepos', 'Local'),
    [string]$DispatchTokenFile = (Join-Path $env:USERPROFILE '.vwstate-lab-dispatch.txt')
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\LabCommon.ps1"

if (-not $PlanOnly -and -not $Yes) {
    throw 'Refusing to change anything without -Yes. Run with -PlanOnly first to see what would be removed.'
}

Assert-LabTarget
$vars = Read-LabVars
$owner = $vars.github_owner
$vwstate = "$owner/vwstate-lab"
$tfArgs = @("-chdir=$($script:LabTerraformDir)")

function Get-GhJson([string[]]$ghArgs) {
    # gh's own errors (a missing repo, say) mean "nothing there", not a failure of the teardown.
    $ErrorActionPreference = 'Continue'
    $out = & gh @ghArgs 2>$null | Out-String
    if ($LASTEXITCODE -ne 0 -or -not $out.Trim()) { return $null }
    # Windows PowerShell's ConvertFrom-Json emits a JSON array as one item; assigning it first
    # makes the return unroll it into separate items.
    $parsed = $out | ConvertFrom-Json
    return $parsed
}

# --- What exists ----------------------------------------------------------------------------
$vwstateExists = [bool](Get-GhJson @('api', "repos/$vwstate", '--jq', '{name: .name}'))
$prs = @(); $serviceRepos = @()
if ($vwstateExists) {
    if ($Scope -contains 'PullRequests') {
        $prs = @(Get-GhJson @('pr', 'list', '-R', $vwstate, '--state', 'open', '--limit', '100',
                '--json', 'number,title,headRefName,isDraft') | Where-Object { $_.headRefName -like 'onboard/*' })
    }
    if ($Scope -contains 'ServiceRepos') {
        $files = @(Get-GhJson @('api', "repos/$vwstate/contents/kubernetes/versions"))
        foreach ($f in $files) {
            $m = [regex]::Match([string]$f.name, '^(.+)\.yaml$')
            if (-not $m.Success) { continue }
            $repo = $m.Groups[1].Value
            $info = Get-GhJson @('api', "repos/$owner/$repo", '--jq', '{private: .private, owner: .owner.login}')
            if ($info -and $info.owner -eq $owner) { $serviceRepos += "$owner/$repo" }
        }
    }
}

Write-Host ''
Write-Host "Teardown plan (scope: $($Scope -join ', '))" -ForegroundColor Cyan
if ($Scope -contains 'Azure') { Write-Host "  Azure        terraform destroy of rg-gmnupr-lab (plan below)" }
if ($Scope -contains 'PullRequests') {
    if ($prs) { $prs | ForEach-Object { Write-Host "  Close PR     $vwstate#$($_.number) [$($_.headRefName)] $($_.title)" } }
    else { Write-Host '  PullRequests none open' }
}
if ($Scope -contains 'ServiceRepos') {
    if ($serviceRepos) { $serviceRepos | ForEach-Object { Write-Host "  Delete repo  $_" } }
    else { Write-Host '  ServiceRepos none found' }
}
if ($Scope -contains 'VwstateLab') { Write-Host "  Delete repo  $vwstate $(if (-not $vwstateExists) { '(already gone)' })" }
if ($Scope -contains 'Local') {
    foreach ($p in @($script:LabKubeconfig, $DispatchTokenFile)) {
        Write-Host "  Delete file  $p $(if (-not (Test-Path $p)) { '(not present)' })"
    }
}
Write-Host '  By hand      revoke the dispatch token (GitHub settings > fine-grained tokens); unregister the components in Backstage'
Write-Host ''

if ($PlanOnly) {
    if ($Scope -contains 'Azure') {
        Invoke-LabNative terraform ($tfArgs + @('plan', '-destroy', '-input=false', "-var-file=$($script:LabVarsFile)"))
    }
    return
}

# --- Do it -----------------------------------------------------------------------------------
$deletingRepos = ($serviceRepos.Count -gt 0) -or (($Scope -contains 'VwstateLab') -and $vwstateExists)
if ($deletingRepos) {
    $scopes = (& gh auth status 2>&1 | Out-String)
    if ($scopes -notmatch 'delete_repo') {
        throw "The gh token lacks the delete_repo scope. Run: gh auth refresh -h github.com -s delete_repo"
    }
}

if ($Scope -contains 'Azure') {
    Invoke-LabNative terraform ($tfArgs + @('destroy', '-auto-approve', '-input=false', "-var-file=$($script:LabVarsFile)"))
    $exists = (& az group exists --subscription $vars.subscription_id --name 'rg-gmnupr-lab').Trim()
    if ($exists -ne 'false') { throw "rg-gmnupr-lab still exists (az group exists = $exists)" }
    Write-Host 'Azure: rg-gmnupr-lab is gone.'
}
foreach ($pr in $prs) {
    Invoke-LabNative gh @('pr', 'close', "$($pr.number)", '-R', $vwstate, '--delete-branch',
        '--comment', 'Closed by Remove-Lab.ps1: the lab is being torn down.')
}
foreach ($repo in $serviceRepos) {
    Invoke-LabNative gh @('repo', 'delete', $repo, '--yes')
}
if (($Scope -contains 'VwstateLab') -and $vwstateExists) {
    Invoke-LabNative gh @('repo', 'delete', $vwstate, '--yes')
}
if ($Scope -contains 'Local') {
    foreach ($p in @($script:LabKubeconfig, $DispatchTokenFile)) {
        if (Test-Path $p) { Remove-Item $p -Force -Confirm:$false; Write-Host "Deleted $p" }
    }
}
Write-Host 'Teardown done. Still by hand: revoke the dispatch token in GitHub, unregister the components in Backstage.'
