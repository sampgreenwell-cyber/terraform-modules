<#
.SYNOPSIS
    Blocks lab-specific values from being committed to this public repo.

.DESCRIPTION
    Scans the files git would commit under labs/ (staged, or all tracked and
    untracked-but-not-ignored with -All) for GUIDs, email addresses, IPv4
    addresses and the work names listed in the local terraform.tfvars. The placeholders in
    terraform.tfvars.example are allowed.
    Run before every commit and push.
#>
[CmdletBinding()]
param([switch]$All)

$ErrorActionPreference = 'Stop'
$repo = (& git -C $PSScriptRoot rev-parse --show-toplevel).Trim()

if ($All) {
    $files = & git -C $repo ls-files --cached --others --exclude-standard -- labs/
}
else {
    $files = & git -C $repo diff --cached --name-only --diff-filter=ACMR -- labs/
}

$patterns = @{
    'GUID'  = '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b'
    'email' = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'
    'IPv4'  = '\b(?:\d{1,3}\.){3}\d{1,3}\b'
}
# Work names: the orgs and the literal words of the cluster pattern from the local (gitignored)
# terraform.tfvars, so this script itself names no employer.
$varsFile = Join-Path $PSScriptRoot 'terraform.tfvars'
if (Test-Path $varsFile) {
    $words = @()
    foreach ($line in Get-Content $varsFile) {
        if ($line -match '^\s*work_github_orgs\s*=\s*\[(.*)\]') {
            $words += [regex]::Matches($Matches[1], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
        }
        elseif ($line -match '^\s*work_kube_context_pattern\s*=\s*"([^"]*)"') {
            $words += [regex]::Matches($Matches[1], '[A-Za-z0-9]{4,}') | ForEach-Object { $_.Value }
        }
    }
    # No trailing boundary: real names carry suffixes (a cluster pattern's word plus a number).
    if ($words) { $patterns['work name'] = '(?i)(?<![A-Za-z0-9])(' + (($words | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')' }
}
else {
    Write-Warning "No $varsFile here, so work names are not checked."
}
# Documentation placeholders (RFC 5737 IP, example.com, all-zero GUID).
$allowed = '00000000-0000-0000-0000-000000000000|@example\.com|203\.0\.113\.\d+|0\.0\.0\.0|10\.0\.0\.0|10\.\d+\.0\.0'

$hits = @()
foreach ($f in $files) {
    $path = Join-Path $repo $f
    if (-not (Test-Path $path -PathType Leaf)) { continue }
    $n = 0
    foreach ($line in Get-Content $path) {
        $n++
        foreach ($kind in $patterns.Keys) {
            foreach ($m in [regex]::Matches($line, $patterns[$kind])) {
                if ($m.Value -notmatch $allowed) { $hits += "${f}:${n}: $kind '$($m.Value)'" }
            }
        }
    }
}

if ($hits.Count -gt 0) {
    Write-Host "Lab-specific values found; do not commit:" -ForegroundColor Red
    $hits | ForEach-Object { Write-Host "  $_" }
    exit 1
}
Write-Host "No GUIDs, emails, IPs or work names in $(@($files).Count) file(s) under labs/."
exit 0
