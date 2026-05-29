param(
    [string]$InventoryPath = (Join-Path (Split-Path -Parent $PSCommandPath) '..\data\project-inventory.csv'),
    [string]$OutputRoot = (Join-Path (Split-Path -Parent $PSCommandPath) '..\project-preserve'),
    [switch]$SkipNoRemoteBundles,
    [switch]$BundleOnly
)

$projects = Import-Csv $InventoryPath
$outputBase = [System.IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path $outputBase)) { New-Item -ItemType Directory -Force -Path $outputBase | Out-Null }

$ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$session = Join-Path $outputBase $ts
New-Item -ItemType Directory -Force -Path $session | Out-Null

$manifest = @()

foreach ($p in $projects) {
    $safe = ($p.ProjectName -replace '[^A-Za-z0-9._-]', '_')
    $target = Join-Path $session $safe
    New-Item -ItemType Directory -Force -Path $target | Out-Null

    if ($BundleOnly -or [string]::IsNullOrWhiteSpace($p.RemoteUrl)) {
        $bundlePath = Join-Path $target 'repository.bundle'
        try {
            git -C $p.ProjectPath bundle create $bundlePath --all | Out-Null
            $created = 'bundle'
        } catch {
            $created = 'bundle-failed'
        }
    } else {
        $created = 'remote-only'
    }

    if ($SkipNoRemoteBundles -and [string]::IsNullOrWhiteSpace($p.RemoteUrl)) {
        continue
    }

    $meta = [pscustomobject]@{
        ProjectName = $p.ProjectName
        ProjectPath = $p.ProjectPath
        ProjectType = $p.ProjectType
        RemoteUrl = $p.RemoteUrl
        GitBranch = $p.GitBranch
        LastCommitDate = $p.LastCommitDate
        TaskCompletion = if ([string]::IsNullOrWhiteSpace($p.CompletionPercent)) { 'No checklist metadata available' } else { "$($p.CompletionPercent)%" }
        PreservationMode = $created
    }

    $meta | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 (Join-Path $target 'project-preservation.json')
    Copy-Item -Path (Join-Path (Split-Path -Parent $PSCommandPath) '..\notion\project-inventory.notion.md') -Destination (Join-Path $target 'project-inventory.notion.md') -ErrorAction SilentlyContinue
    $manifest += $meta
}

$manifest | Export-Csv -Path (Join-Path $session 'preservation-manifest.csv') -NoTypeInformation -Encoding utf8
$manifest | ConvertTo-Json -Depth 6 | Out-File -Encoding utf8 (Join-Path $session 'preservation-manifest.json')

Write-Output "Preservation session complete: $session"
