<#
.SYNOPSIS
    After `terraform apply`: writes the lab kubeconfig and the Envoy TLS secrets.

.DESCRIPTION
    1. Fetches cluster credentials into labs/gmnupr-lab/kubeconfig (gitignored) with
       context name from terraform.tfvars. Your default kubeconfig is not touched.
    2. Creates Secrets gmn-upr-{edge,k8s,pm}-router in gemini-routing with the keys
       the Envoy configs read: tls.crt, tls.key (encrypted) and password.
       Keys are generated with openssl, so no key material enters Terraform state.
       Existing secrets are kept unless -RotateCerts is given.

.EXAMPLE
    .\Initialize-LabCluster.ps1 -WhatIf
    .\Initialize-LabCluster.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$RotateCerts)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\LabCommon.ps1"

Assert-LabTarget
$vars = Read-LabVars
$out = Get-LabOutputs
$tiers = 'edge', 'k8s', 'pm'

if ($PSCmdlet.ShouldProcess($script:LabKubeconfig, "Write admin credentials for $($out.aks_name) (context $($vars.kube_context))")) {
    Invoke-LabNative az @('aks', 'get-credentials', '--subscription', $vars.subscription_id,
        '--resource-group', $out.resource_group, '--name', $out.aks_name, '--admin',
        '--file', $script:LabKubeconfig, '--context', $vars.kube_context, '--overwrite-existing', '--only-show-errors')
    # With --admin, az appends "-admin" to the context name; restore the expected one.
    $adminContext = "$($vars.kube_context)-admin"
    $contexts = @(& kubectl --kubeconfig $script:LabKubeconfig config get-contexts -o name)
    if ($contexts -contains $adminContext) {
        if ($contexts -contains $vars.kube_context) {
            Invoke-LabNative kubectl @('--kubeconfig', $script:LabKubeconfig, 'config', 'delete-context', $vars.kube_context)
        }
        Invoke-LabNative kubectl @('--kubeconfig', $script:LabKubeconfig, 'config', 'rename-context', $adminContext, $vars.kube_context)
        Invoke-LabNative kubectl @('--kubeconfig', $script:LabKubeconfig, 'config', 'use-context', $vars.kube_context)
    }
    Assert-LabTarget -Kube
}

if ($PSCmdlet.ShouldProcess('namespace gemini-routing', 'Create if missing')) {
    $ns = & kubectl --kubeconfig $script:LabKubeconfig --context $vars.kube_context create namespace gemini-routing --dry-run=client -o yaml
    $ns | & kubectl --kubeconfig $script:LabKubeconfig --context $vars.kube_context apply -f -
    if ($LASTEXITCODE -ne 0) { throw 'Could not create namespace gemini-routing' }
}

$openssl = Get-LabOpenSsl
foreach ($tier in $tiers) {
    $name = "gmn-upr-$tier-router"
    $exists = $false
    if (Test-Path $script:LabKubeconfig) {
        # --ignore-not-found prints nothing (and exits 0) when the secret is missing.
        $found = & kubectl --kubeconfig $script:LabKubeconfig --context $vars.kube_context -n gemini-routing get secret $name -o name --ignore-not-found
        $exists = [bool]$found
    }
    if ($exists -and -not $RotateCerts) {
        Write-Host "Secret $name exists; keeping it (use -RotateCerts to replace)."
        continue
    }
    if (-not $PSCmdlet.ShouldProcess("secret gemini-routing/$name", 'Generate self-signed cert, encrypted key and password')) { continue }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("gmnupr-lab-tls-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        $bytes = New-Object byte[] 32
        $rng.GetBytes($bytes)
        $password = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
        # No trailing newline: Envoy reads the file's bytes as the password.
        [IO.File]::WriteAllText((Join-Path $tmp 'password'), $password)

        Invoke-LabNative $openssl @('req', '-x509', '-newkey', 'rsa:2048', '-sha256', '-days', '30',
            '-subj', "/CN=$name", '-addext', "subjectAltName=DNS:dev1-gmnupr-api.lab.example,DNS:upr-$tier-router.gemini-routing.svc",
            '-keyout', (Join-Path $tmp 'tls.key'), '-out', (Join-Path $tmp 'tls.crt'),
            '-passout', "file:$(Join-Path $tmp 'password')")

        $yaml = & kubectl --kubeconfig $script:LabKubeconfig --context $vars.kube_context -n gemini-routing create secret generic $name `
            "--from-file=tls.crt=$(Join-Path $tmp 'tls.crt')" "--from-file=tls.key=$(Join-Path $tmp 'tls.key')" `
            "--from-file=password=$(Join-Path $tmp 'password')" --dry-run=client -o yaml
        $yaml | & kubectl --kubeconfig $script:LabKubeconfig --context $vars.kube_context apply -f -
        if ($LASTEXITCODE -ne 0) { throw "Could not apply secret $name" }
        Write-Host "Secret $name written."
    }
    finally {
        Remove-Item -Recurse -Force $tmp -Confirm:$false
    }
}
