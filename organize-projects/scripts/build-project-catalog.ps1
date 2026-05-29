param(
    [string[]]$AdditionalRoots = @(
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\OneDrive"
    )
)

$ErrorActionPreference = 'Continue'

$scanRoots = @($AdditionalRoots + "$env:USERPROFILE\Projects", "$env:USERPROFILE\Code", "$env:USERPROFILE\Src", "$env:USERPROFILE\Source", "$env:USERPROFILE\github", "$env:USERPROFILE\.codex", "$env:USERPROFILE\Documents\Codex") |
    ForEach-Object { $_ } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_) } |
    Select-Object -Unique

$projectList = @{}
$skipSegmentRegex = '\\(node_modules|\.cache|\.venv|venv|\.gradle|\.pnpm-store|\.nuget|\.rustup|\.ivy2|\.m2|\.npm|\.yarn|Library|AppData|AppData\\LocalLow|AppData\\Local\\Temp|AppData\\Roaming\\Temp)\\'

function Get-ProjectType {
    param([string]$Path)

    $types = @()
    if (Test-Path (Join-Path $Path 'package.json')) { $types += 'Node.js' }
    if ((Test-Path (Join-Path $Path 'pyproject.toml')) -or (Test-Path (Join-Path $Path 'requirements.txt')) -or (Test-Path (Join-Path $Path 'poetry.lock'))) { $types += 'Python' }
    if (Test-Path (Join-Path $Path 'go.mod')) { $types += 'Go' }
    if (Test-Path (Join-Path $Path 'Cargo.toml')) { $types += 'Rust' }
    if (Test-Path (Join-Path $Path 'pom.xml')) { $types += 'Java/Kotlin' }
    if ((Test-Path (Join-Path $Path 'build.gradle')) -or (Test-Path (Join-Path $Path 'build.gradle.kts'))) { $types += 'Java/Kotlin' }
    if (Get-ChildItem -Path $Path -Filter '*.csproj' -File -ErrorAction SilentlyContinue | Select-Object -First 1) { $types += '.NET' }
    if (Test-Path (Join-Path $Path 'composer.json')) { $types += 'PHP' }
    if (Test-Path (Join-Path $Path 'Gemfile')) { $types += 'Ruby' }
    if (Test-Path (Join-Path $Path 'pubspec.yaml')) { $types += 'Flutter/Dart' }
    if (Test-Path (Join-Path $Path 'mix.exs')) { $types += 'Elixir' }
    if (Test-Path (Join-Path $Path 'build.sbt')) { $types += 'Scala' }
    if (Test-Path (Join-Path $Path 'CMakeLists.txt')) { $types += 'C++/CMake' }
    if ((Test-Path (Join-Path $Path 'docker-compose.yml')) -or (Test-Path (Join-Path $Path 'docker-compose.yaml')) -or (Test-Path (Join-Path $Path 'Dockerfile'))) { $types += 'Container' }
    if ($types.Count -eq 0) { return @('Unidentified') }
    return $types | Select-Object -Unique
}

function Get-ProjectStats {
    param([string]$Path)
    $allItems = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\.git($|\\)' }
    $files = $allItems | Where-Object { -not $_.PSIsContainer }
    $sizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
    return [pscustomobject]@{
        SizeMB = [math]::Round(($sizeBytes/1MB),2)
        FileCount = $files.Count
        DirectoryCount = ($allItems | Where-Object { $_.PSIsContainer }).Count
    }
}

function Get-TaskCompletion {
    param([string]$Path)
    $markdownFiles = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\.git($|\\)' -and $_.Extension -in @('.md','.txt','.mdx') -and $_.Length -lt 2MB }

    $open = 0
    $done = 0
    $todoHits = 0
    $taskHintSources = 0

    foreach ($file in $markdownFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $open += ([regex]::Matches($content, '(?m)^\s*[-*]\s*\[\s\]\s+')).Count
        $done += ([regex]::Matches($content, '(?m)^\s*[-*]\s*\[[xX]\]\s+')).Count
        $todoHits += ([regex]::Matches($content, '\bTODO\b|\bFIXME\b|\bXXX\b|\bHACK\b').Count)
        if ($content -match '(?m)^\s*##\s*Task|\bTODO\b|\bChecklist\b') { $taskHintSources += 1 }
    }

    return [pscustomobject]@{
        TaskOpen = $open
        TaskDone = $done
        TaskTotal = $open + $done
        TaskCompletionPercent = if (($open + $done) -gt 0) { [math]::Round(($done / ($open + $done) * 100), 2) } else { $null }
        PlainTodoHintCount = $todoHits
        TaskDocumentedFiles = $taskHintSources
    }
}

$gitRoots = @()
foreach ($root in $scanRoots) {
    Write-Host "Scanning: $root"
    $gitDirs = Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq '.git' -and $_.FullName -notmatch $skipSegmentRegex }

    foreach ($gitDir in $gitDirs) {
        $proj = Split-Path -Parent $gitDir.FullName
        if ($projectList.ContainsKey($proj)) { continue }
        $projectList[$proj] = $true
        $path = (Resolve-Path $proj).Path

        $branch = 'unknown'
        $lastCommitDate = ''
        $lastCommitMessage = ''
        $remoteUrl = ''
        $ahead = 0
        $behind = 0
        $dirty = $false
        $statusCount = 0
        $recentCommits30 = 0

        try { $branch = (git -C $path rev-parse --abbrev-ref HEAD).Trim() } catch {}
        try {
            $statusOut = git -C $path status --short
            if ($statusOut) { $statusCount = @($statusOut).Count; $dirty = $true }
        } catch {}
        try {
            $lastCommitUnix = (git -C $path log -1 --format='%ct').Trim()
            if ($lastCommitUnix) { $lastCommitDate = ([DateTimeOffset]::FromUnixTimeSeconds([int64]$lastCommitUnix).ToLocalTime()).ToString('yyyy-MM-dd HH:mm:ss') }
            $lastCommitMessage = (git -C $path log -1 --format='%s').Trim()
        } catch {}
        try { $remoteUrl = ((git -C $path remote get-url origin 2>$null) -join [Environment]::NewLine).Trim() } catch {}
        try {
            $upstream = (git -C $path rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null).Trim()
            if ($upstream) { $ahead = [int](git -C $path rev-list --count "$upstream..HEAD"); $behind = [int](git -C $path rev-list --count "HEAD..$upstream") }
        } catch {}
        try { $recentCommits30 = [int](git -C $path rev-list --count --since='30 days ago' HEAD) } catch {}

        $stats = Get-ProjectStats -Path $path
        $types = Get-ProjectType -Path $path
        $task = Get-TaskCompletion -Path $path
        $ageDays = ''
        if ($lastCommitDate) { try { $ageDays = [math]::Round((New-TimeSpan -Start ([datetime]$lastCommitDate) -End (Get-Date)).TotalDays,1) } catch {} }

        $gitRoots += [pscustomobject]@{
            ProjectPath = $path
            ProjectName = Split-Path -Leaf $path
            ProjectType = ($types -join ', ')
            SizeMB = $stats.SizeMB
            DirectoryCount = $stats.DirectoryCount
            FileCount = $stats.FileCount
            GitBranch = $branch
            LastCommitDate = $lastCommitDate
            LastCommitAgeDays = $ageDays
            LastCommitMessage = $lastCommitMessage
            HeadAhead = $ahead
            HeadBehind = $behind
            RemoteUrl = $remoteUrl
            HasUncommittedChanges = $dirty
            UncommittedFileCount = $statusCount
            RecentCommits30d = $recentCommits30
            TaskOpen = $task.TaskOpen
            TaskDone = $task.TaskDone
            TaskTotal = $task.TaskTotal
            CompletionPercent = if ($null -eq $task.TaskCompletionPercent) { '' } else { $task.TaskCompletionPercent }
            PlainTodoHits = $task.PlainTodoHintCount
            TaskDocumentedFiles = $task.TaskDocumentedFiles
        }
    }
}

$ordered = $gitRoots | Sort-Object ProjectType,ProjectName
$reportDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$dataDir = Join-Path (Split-Path -Parent $PSCommandPath) '..\data'
$notionDir = Join-Path (Split-Path -Parent $PSCommandPath) '..\notion'

$ordered | Export-Csv -Path (Join-Path $dataDir 'project-inventory.csv') -NoTypeInformation -Encoding UTF8
$ordered | ConvertTo-Json -Depth 6 | Out-File -Encoding utf8 (Join-Path $dataDir 'project-inventory.json')

$md = @()
$md += '# Project Inventory and Preservation Report'
$md += "Generated: $reportDate"
$md += ''
$md += '## Scan coverage'
$md += ''
$md += ('- Roots scanned: ' + ($scanRoots -join ', '))
$md += ('- Git projects found: ' + $ordered.Count)
$md += ''
$md += '## Executive summary'
$md += ''
$totalSize = ($ordered | Measure-Object -Property SizeMB -Sum).Sum
$md += ('- Total repository payload (excluding .git folders): ' + [math]::Round([double]$totalSize,2) + ' MB')
$md += ('- Repositories with uncommitted changes: ' + @($ordered | Where-Object { $_.HasUncommittedChanges }).Count)
$md += ('- Repositories without explicit task checklists: ' + @($ordered | Where-Object { $_.TaskTotal -le 0 }).Count)
$md += ''
$md += '## Detailed project registry'
$md += ''

foreach ($p in $ordered) {
    $completion = if ([string]::IsNullOrWhiteSpace($p.CompletionPercent.ToString())) { 'No checklist metadata available' } else { "$($p.CompletionPercent)% (from markdown task lists)" }
    $dirty = if ($p.HasUncommittedChanges) { 'uncommitted changes present' } else { 'clean working tree' }
    $ageLabel = if ([string]::IsNullOrWhiteSpace($p.LastCommitAgeDays.ToString())) { 'n/a' } else { "$($p.LastCommitAgeDays) days since last commit" }

    $md += "### $($p.ProjectName)"
    $md += ''
    $md += ('- Path: `' + $p.ProjectPath + '`')
    $md += ('- Project type(s): ' + $p.ProjectType)
    $md += ('- Size: ' + $p.SizeMB + ' MB | Files: ' + $p.FileCount + ' | Folders: ' + $p.DirectoryCount)
    $md += ('- Git branch: ' + $p.GitBranch + ' | ' + $dirty)
    $md += ('- Last commit: ' + $p.LastCommitDate + ' (' + $ageLabel + ')')
    $md += ('- Last commit message: ' + $p.LastCommitMessage)
    $md += ('- Remote: ' + $(if ([string]::IsNullOrWhiteSpace($p.RemoteUrl)) { 'none' } else { $p.RemoteUrl }))
    $md += ('- Sync posture: ahead + ' + $p.HeadAhead + ', behind + ' + $p.HeadBehind + ' (vs upstream if configured)')
    $md += ('- Recent activity (30d): ' + $p.RecentCommits30d + ' commits')
    $md += ('- Completion: ' + $completion)
    $md += ('- Task metadata: total task markers=' + $p.TaskTotal + ' | done=' + $p.TaskDone + ' | open=' + $p.TaskOpen + ' | markdown/plain-todo hits=' + $p.PlainTodoHits + ' in ' + $p.TaskDocumentedFiles + ' files')
    $md += ''
}

$md += '## Backup recommendation'
$md += ''
$md += 'For each listed repository, preserve this report together with the repository remote or local git history before cleanup.'
$md += 'Repos with no open task markers and no uncommitted changes are usually safe to treat as archived unless active requirements exist.'
$md += ''
$md += 'Completion interpretation used here:'
$md += '- Completion% only counts markdown task checkboxes using `- [ ]` and `- [x]` / `- [X]` notation.'
$md += '- If a project has no checklist artifacts, completion is marked as "No checklist metadata available" and should be confirmed manually.'

$reportPath = Join-Path $dataDir 'project-inventory.md'
$notionPath = Join-Path $notionDir 'project-inventory.notion.md'
$md -join "`r`n" | Out-File -Encoding utf8 $reportPath
$md -join "`r`n" | Out-File -Encoding utf8 $notionPath

Write-Output "Inventory complete. Report: $reportPath"
Write-Output "JSON: $(Join-Path $dataDir 'project-inventory.json')"
Write-Output "CSV: $(Join-Path $dataDir 'project-inventory.csv')"
