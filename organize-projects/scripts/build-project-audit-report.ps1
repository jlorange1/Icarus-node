param(
    [string]$InventoryPath = (Join-Path (Split-Path -Parent $PSCommandPath) '..\data\project-inventory.csv'),
    [string]$OutputDir = (Join-Path (Split-Path -Parent $PSCommandPath) '..\data'),
    [string]$NotionOutput = (Join-Path (Split-Path -Parent $PSCommandPath) '..\notion\project-audit-notion.md')
)

$inv = Import-Csv -Path $InventoryPath
if (-not $inv) {
    Write-Error "Inventory file is empty or missing: $InventoryPath"
    exit 1
}

function To-DoubleOrNull {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $clean = $Value.Trim()
    $v = 0.0
    if ([double]::TryParse($clean, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)) { return [math]::Round($v,2) }
    if ([double]::TryParse($clean, [ref]$v)) { return [math]::Round($v,2) }
    return $null
}

function To-IntOrNull {
    param([string]$Value)
    $v = 0
    if ([int]::TryParse($Value, [ref]$v)) { return $v }
    return $null
}

$rows = @()
foreach ($p in $inv) {
    $sizeMB = To-DoubleOrNull $p.SizeMB
    $fileCount = To-IntOrNull $p.FileCount
    $dirCount = To-IntOrNull $p.DirectoryCount
    $recent30 = To-IntOrNull $p.RecentCommits30d
    $ageDays = To-DoubleOrNull $p.LastCommitAgeDays
    $completion = To-DoubleOrNull $p.CompletionPercent
    $dirty = ([string]$p.HasUncommittedChanges).Trim().ToLower() -eq 'true'
    $taskTotal = To-IntOrNull $p.TaskTotal
    $taskOpen = To-IntOrNull $p.TaskOpen
    $taskDone = To-IntOrNull $p.TaskDone
    $remote = [string]::IsNullOrWhiteSpace($p.RemoteUrl) -eq $false

    if ($null -eq $completion) {
        $completionLabel = 'No checklist metadata available'
        $completionRange = 'Unknown'
    } elseif ($completion -ge 90) {
        $completionLabel = "$completion% (high)"
        $completionRange = 'High'
    } elseif ($completion -ge 50) {
        $completionLabel = "$completion% (medium)"
        $completionRange = 'Medium'
    } else {
        $completionLabel = "$completion% (low)"
        $completionRange = 'Low'
    }

    if ($ageDays -eq $null) {
        $staleness = 'Unknown'
    } elseif ($ageDays -ge 365) {
        $staleness = 'Dormant'
    } elseif ($ageDays -ge 180) {
        $staleness = 'Cold'
    } elseif ($ageDays -ge 90) {
        $staleness = 'Warm'
    } else {
        $staleness = 'Active'
    }

    if ($dirty) {
        $risk = 'Critical'
        $retentionAction = 'Do not delete now; uncommitted changes exist'
    } elseif (-not $remote) {
        $risk = 'Moderate'
        $retentionAction = 'No remote; preserve local or export bundle before deletion'
    } elseif ($recent30 -ge 2 -and $ageDays -ne $null -and $ageDays -lt 30) {
        $risk = 'Active'
        $retentionAction = 'Keep locally or archive after current sprint'
    } elseif ($completionRange -eq 'Low') {
        $risk = 'Moderate'
        $retentionAction = 'Retain for completion work; evaluate scope before deletion'
    } elseif ($staleness -in @('Dormant', 'Cold')) {
        $risk = 'Low'
        $retentionAction = 'Safe candidate for local cleanup after confirmation backup'
    } else {
        $risk = 'Low'
        $retentionAction = 'Safe cleanup candidate if remote is authoritative'
    }

    $rows += [pscustomobject]@{
        ProjectName = $p.ProjectName
        ProjectPath = $p.ProjectPath
        ProjectType = $p.ProjectType
        SizeMB = $sizeMB
        FileCount = $fileCount
        DirectoryCount = $dirCount
        GitBranch = $p.GitBranch
        LastCommitDate = $p.LastCommitDate
        LastCommitAgeDays = $ageDays
        Staleness = $staleness
        RemoteConfigured = $remote
        RemoteUrl = $p.RemoteUrl
        HasUncommittedChanges = $dirty
        RecentCommits30d = $recent30
        CompletionPercent = $completion
        CompletionLabel = $completionLabel
        CompletionRange = $completionRange
        TaskTotal = $taskTotal
        TaskOpen = $taskOpen
        TaskDone = $taskDone
        PlainTodoHits = To-IntOrNull $p.PlainTodoHits
        RiskTier = $risk
        RetentionAction = $retentionAction
        ReportedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
}

$ordered = $rows | Sort-Object -Property @{Expression='HasUncommittedChanges';Descending=$true}, @{Expression='RiskTier'}, @{Expression='ProjectType'}, @{Expression='ProjectName'}

$csv = Join-Path $OutputDir 'project-context-detailed.csv'
$json = Join-Path $OutputDir 'project-context-detailed.json'
$md = Join-Path $OutputDir 'project-context-detailed.md'

$ordered | Export-Csv -Path $csv -NoTypeInformation -Encoding utf8
$ordered | ConvertTo-Json -Depth 8 | Out-File -Encoding utf8 $json

$riskCount = $ordered | Group-Object RiskTier | Sort-Object Name
$completionBuckets = @{
    High = @($ordered | Where-Object { $_.CompletionRange -eq 'High' }).Count
    Medium = @($ordered | Where-Object { $_.CompletionRange -eq 'Medium' }).Count
    Low = @($ordered | Where-Object { $_.CompletionRange -eq 'Low' }).Count
    Unknown = @($ordered | Where-Object { $_.CompletionRange -eq 'Unknown' }).Count
}
$staleBuckets = @{
    Active = @($ordered | Where-Object { $_.Staleness -eq 'Active' }).Count
    Warm = @($ordered | Where-Object { $_.Staleness -eq 'Warm' }).Count
    Cold = @($ordered | Where-Object { $_.Staleness -eq 'Cold' }).Count
    Dormant = @($ordered | Where-Object { $_.Staleness -eq 'Dormant' }).Count
    Unknown = @($ordered | Where-Object { $_.Staleness -eq 'Unknown' }).Count
}
$noRemote = @($ordered | Where-Object { -not $_.RemoteConfigured }).Count
$dirtyCount = @($ordered | Where-Object { $_.HasUncommittedChanges }).Count
$activeCandidates = @($ordered | Where-Object { $_.RetentionAction -eq 'Safe cleanup candidate for local cleanup after confirmation backup' -or $_.RetentionAction -eq 'Safe cleanup candidate if remote is authoritative' }).Count

$report = @()
$report += '# Project Audit and Retention Report'
$report += "Generated: $((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
$report += ''
$report += '## Executive summary'
$report += ('- Total scanned projects: ' + $ordered.Count)
$report += ('- Dirty repos: ' + $dirtyCount)
$report += ('- Projects with no remote configured: ' + $noRemote)
$report += ('- Cleanup candidates (low-risk): ' + $activeCandidates)
$report += ('- Total payload (excluding .git): ' + [math]::Round((($ordered | Measure-Object -Property SizeMB -Sum).Sum),2) + ' MB')
$report += ''
$report += '## Completion profile'
$report += ("- High: $($completionBuckets.High)")
$report += ("- Medium: $($completionBuckets.Medium)")
$report += ("- Low: $($completionBuckets.Low)")
$report += ("- No metadata: $($completionBuckets.Unknown)")
$report += ''
$report += '## Staleness profile'
$report += ("- Active (< 90d): $($staleBuckets.Active)")
$report += ("- Warm (90-179d): $($staleBuckets.Warm)")
$report += ("- Cold (180-364d): $($staleBuckets.Cold)")
$report += ("- Dormant (365d+): $($staleBuckets.Dormant)")
$report += ("- Unknown: $($staleBuckets.Unknown)")
$report += ''
$report += '## Risk bucket'
foreach ($g in $riskCount) {
    $report += ('- ' + $g.Name + ': ' + $g.Count)
}
$report += ''
$report += '## Per-project context and retention recommendation'
$report += ''
foreach ($p in $ordered) {
    $dirtyLabel = if ($p.HasUncommittedChanges) { 'YES (do not delete before review)' } else { 'NO' }
    $report += ('### ' + $p.ProjectName)
    $report += ('- Path: ' + $p.ProjectPath)
    $report += ('- Type(s): ' + $p.ProjectType)
    $report += ('- Size: ' + $p.SizeMB + ' MB | Files: ' + $p.FileCount + ' | Folders: ' + $p.DirectoryCount)
    $report += ('- Branch/state: ' + $p.GitBranch + ' | Dirty: ' + $dirtyLabel)
    $report += ('- Last commit age: ' + $p.LastCommitAgeDays + ' days | Recent commits (30d): ' + $p.RecentCommits30d)
    $report += ('- Completion: ' + $p.CompletionLabel)
    if ($p.TaskTotal -gt 0) {
        $report += ('- Task markers: total=' + $p.TaskTotal + ', done=' + $p.TaskDone + ', open=' + $p.TaskOpen + ', plain TODO hits=' + $p.PlainTodoHits)
    } else {
        $report += '- Task markers: none detected (no markdown checklist metadata)'
    }
    $report += '- Remote configured: ' + $(if ($p.RemoteConfigured) { 'Yes' } else { 'No' })
    $report += ('- Remote URL: ' + $p.RemoteUrl)
    $report += ('- Staleness: ' + $p.Staleness)
    $report += ('- Risk tier: ' + $p.RiskTier)
    $report += ('- Retention action: ' + $p.RetentionAction)
    $report += ''
}

$report += '## Runbook'
$report += ''
$report += '- "Active" or "Warm" repos with clean state are usually safe to pause but keep local if you need fast context restore.'
$report += '- "Cold" or "Dormant" repos with clean state and remote history can be pruned after bundle verification.'
$report += '- Never delete "Critical" tier before exporting working tree state + bundle/remote checkpoint.'
$report += '- Run `preserve-project-bundles.ps1` before any delete pass.'
$report += ''
$report | Out-File -Encoding utf8 $md

$notion = @()
$notion += '# Project Audit (Notion Import)'
$notion += "Generated: $((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
$notion += ''
$notion += '## Summary'
$notion += "- Total projects: $($ordered.Count)"
$notion += "- Completion high: $($completionBuckets.High)"
$notion += "- Completion medium: $($completionBuckets.Medium)"
$notion += "- Completion low: $($completionBuckets.Low)"
$notion += "- Completion unknown: $($completionBuckets.Unknown)"
$notion += ''
$notion += '## Risk table'
$notion += '| Project | Dirty | Remote | Completion | Staleness | Risk | Action |'
$notion += '|---|---|---|---:|---|---|---|'
foreach ($p in $ordered) {
    $completionDisplay = if ($p.CompletionPercent -ne $null) { "$($p.CompletionPercent)%" } else { 'No checklist metadata' }
    $notion += ('| ' + $p.ProjectName + ' | ' + $p.HasUncommittedChanges + ' | ' + $p.RemoteConfigured + ' | ' + $completionDisplay + ' | ' + $p.Staleness + ' | ' + $p.RiskTier + ' | ' + $p.RetentionAction + ' |')
}
$notion | Out-File -Encoding utf8 $NotionOutput

Write-Output "Project context CSV: $csv"
Write-Output "Project context JSON: $json"
Write-Output "Project context MD: $md"
Write-Output "Notion import MD: $NotionOutput"
