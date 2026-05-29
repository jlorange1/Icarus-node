param(
    [switch]$OnlyReport,
    [switch]$Aggressive
)

$basePath = (Resolve-Path (Join-Path (Split-Path -Parent $PSCommandPath) '..')).Path
$logFile = Join-Path $basePath 'cleanup-report.md'
$deletedBytes = 0
$removedItems = @()
$goPath = if ([string]::IsNullOrWhiteSpace($env:GOPATH)) { Join-Path $env:USERPROFILE 'go' } else { $env:GOPATH }
$runMode = if ($Aggressive) { 'Aggressive' } else { 'Standard' }

$drive = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").DeviceID
$beforeFree = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'").FreeSpace

function Get-Size {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    try {
        $entry = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($entry.PSIsContainer) {
            $sum = Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { -not $_.PSIsContainer } |
                Measure-Object -Property Length -Sum
            return [uint64]$sum.Sum
        } else {
            return [uint64]$entry.Length
        }
    } catch { return 0 }
}

$targets = @(
    @{ Name = 'User temp'; Path = $env:TEMP; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'User local temp'; Path = Join-Path $env:LOCALAPPDATA 'Temp'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Windows temp'; Path = 'C:\Windows\Temp'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Windows prefetch'; Path = 'C:\Windows\Prefetch'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Windows update cache'; Path = 'C:\Windows\SoftwareDistribution\Download'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Recycle Bin'; Path = 'RecycleBin'; RemoveChildren = $false; IsSpecial = $true; Include = @('*') },
    @{ Name = 'Chrome cache'; Path = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default\Cache'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Chrome code cache'; Path = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default\Code Cache'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Edge cache'; Path = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Cache'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Edge code cache'; Path = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Code Cache'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'npm cache'; Path = Join-Path $env:LOCALAPPDATA 'npm-cache'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'pnpm cache'; Path = Join-Path $env:LOCALAPPDATA 'pnpm-cache'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'yarn cache'; Path = Join-Path $env:LOCALAPPDATA 'Yarn'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'pip cache'; Path = Join-Path $env:LOCALAPPDATA 'pip\Cache'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Go module cache'; Path = Join-Path $goPath 'pkg\mod'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Cargo registry'; Path = Join-Path $env:USERPROFILE '.cargo\registry'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Cargo git cache'; Path = Join-Path $env:USERPROFILE '.cargo\git'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Maven package cache'; Path = Join-Path $env:USERPROFILE '.m2\repository'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'NuGet global packages'; Path = Join-Path $env:USERPROFILE '.nuget\packages'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'Conda pkgs cache'; Path = Join-Path $env:USERPROFILE '.conda\pkgs'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
    @{ Name = 'npm cache root'; Path = Join-Path $env:USERPROFILE '.npm'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') }
)

if ($Aggressive) {
    $targets += @(
        @{ Name = 'Windows icon cache'; Path = Join-Path $env:LOCALAPPDATA 'IconCache.db'; RemoveChildren = $false; IsSpecial = $false; Include = @('*') },
        @{ Name = 'Windows logs cache'; Path = Join-Path $env:WINDIR 'Logs'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
        @{ Name = 'Windows internet cache'; Path = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
        @{ Name = 'Windows delivery optimization cache'; Path = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\DeliveryOptimization'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
        @{ Name = 'OneDrive logs'; Path = Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\logs'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') },
        @{ Name = 'Windows defender cache'; Path = Join-Path $env:PROGRAMDATA 'Microsoft\Windows Defender\Scans'; RemoveChildren = $true; IsSpecial = $false; Include = @('*') }
    )
}

if ($OnlyReport) {
    $sizeReport = @()
    foreach ($t in $targets) {
        if ($t.IsSpecial) { continue }
        if ($t.Path.Contains('*')) { continue }
        if (Test-Path -LiteralPath $t.Path) {
            $sizeReport += [pscustomobject]@{ Name = $t.Name; Path = $t.Path; ApproxSizeMB = [math]::Round((Get-Size -Path $t.Path) / 1MB, 2) }
        }
    }

    $report = @()
    $report += '# Deep cleanup candidate size report'
    $report += ('Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $report += ('Mode: ' + $runMode)
    $report += ''
    $report += '## Candidate folder sizes'
    foreach ($r in $sizeReport | Sort-Object Name) {
        $report += ('- ' + $r.Name + ': ' + $r.ApproxSizeMB + ' MB (' + $r.Path + ')')
    }
    $report += ''
    $report += 'Run this script without -OnlyReport to delete these safely removable caches.'
    $report | Out-File -Encoding utf8 $logFile
    Write-Output "Candidate size report written: $logFile"
    return
}

foreach ($target in $targets) {
    $path = $target.Path
    if ($target.IsSpecial) {
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null
            $removedItems += [pscustomobject]@{ Name = $target.Name; RemovedBytes = 0; Item = 'Recycle Bin' }
        } catch {}
        continue
    }

    if (-not (Test-Path -LiteralPath $path)) { continue }
    $paths = @($path)

    foreach ($p in $paths) {
        if ($target.RemoveChildren) {
            $children = Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue
            foreach ($child in $children) {
                try {
                    $before = Get-Size -Path $child.FullName
                    Remove-Item -LiteralPath $child.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    $deletedBytes += $before
                    $removedItems += [pscustomobject]@{ Name = $target.Name; RemovedBytes = $before; Item = $child.FullName }
                } catch {}
            }
        } else {
            $before = Get-Size -Path $p
            try {
                Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
                $deletedBytes += $before
                $removedItems += [pscustomobject]@{ Name = $target.Name; RemovedBytes = $before; Item = $p }
            } catch {}
        }
    }
}

$afterFree = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'").FreeSpace
$deltaMB = [math]::Round((($afterFree - $beforeFree) / 1MB), 2)

$summary = @()
$summary += '# Deep cleanup execution log'
$summary += ('Executed: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$summary += ('Mode: ' + $runMode)
$summary += ''
$summary += ('Drive free before: {0:N2} GB' -f ($beforeFree / 1GB))
$summary += ('Drive free after:  {0:N2} GB' -f ($afterFree / 1GB))
$summary += ('Net reclaimed:    {0:N2} GB' -f ($deltaMB / 1024))
$summary += ''
$summary += '## Removed items'
foreach ($grp in ($removedItems | Group-Object Name)) {
    $bytes = ($grp.Group.RemovedBytes | Measure-Object -Sum).Sum
    $summary += ('- ' + $grp.Name + ': ' + [math]::Round($bytes/1MB,2) + ' MB')
}
$summary | Out-File -Encoding utf8 $logFile
Write-Output "Deep cleanup complete. Reclaimed: $deltaMB MB. Log: $logFile"
