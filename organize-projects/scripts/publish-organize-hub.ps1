param(
    [string]$RepoPath = (Split-Path (Split-Path -Parent $PSCommandPath) -Parent),
    [string]$RemoteRepositoryUrl = '',
    [string]$CommitMessage = 'chore: organize project inventory and preservation hub',
    [switch]$CreateCommit,
    [switch]$Push
)

$ErrorActionPreference = 'Continue'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Output 'Git is not installed in this environment. Install Git to continue.'
    exit 1
}

Push-Location $RepoPath

if (-not (Test-Path ".git")) {
    Write-Output 'No local git repository found. Initializing in-place.'
    git init | Out-Null
    git branch -M main | Out-Null
    git config user.name "Project Cleanup Bot"
    git config user.email "you@example.com"
}

git config core.autocrlf false
git add . --all

if ($CreateCommit) {
    $status = git status --short
    if (-not [string]::IsNullOrWhiteSpace($status)) {
        git commit -m $CommitMessage | Out-Null
        Write-Output "Committed with message: $CommitMessage"
    } else {
        Write-Output 'No changes to commit.'
    }
}

if ([string]::IsNullOrWhiteSpace($RemoteRepositoryUrl)) {
    Write-Output 'No remote URL supplied. Push skipped.'
    Write-Output 'Run again with -RemoteRepositoryUrl and -Push to upload.'
    Write-Output ('Example: powershell -ExecutionPolicy Bypass -File scripts/publish-organize-hub.ps1 -RemoteRepositoryUrl "https://github.com/<owner>/<repo>.git" -CreateCommit -Push')
    exit 0
}

$remotes = git remote
if ($remotes -notcontains 'origin') {
    git remote add origin $RemoteRepositoryUrl | Out-Null
} elseif ($RemoteRepositoryUrl) {
    git remote set-url origin $RemoteRepositoryUrl | Out-Null
}

if (-not $Push) {
    Write-Output ('Remote configured: ' + $RemoteRepositoryUrl)
    Write-Output 'Use -Push to upload this local branch.'
    exit 0
}

if ($RemoteRepositoryUrl -match 'https://([^:@]+):([^@]+)@github.com') {
    Write-Output 'Remote appears to include embedded credentials. Proceeding with push.'
    try {
        git push -u origin main | Out-Null
        Write-Output 'Push completed.'
    } catch {
        Write-Output 'Push failed. Confirm token/credential access.'
        exit 1
    }
} else {
    $token = $env:GITHUB_TOKEN
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Output 'Push requires credentials. Set $env:GITHUB_TOKEN and retry, or use a Git credential manager.'
        exit 1
    }

    $tokened = $RemoteRepositoryUrl -replace 'https://', "https://$token@"
    try {
        git push -u $tokened main | Out-Null
        Write-Output 'Push completed using GITHUB_TOKEN.'
    } catch {
        Write-Output 'Push failed. Confirm repository exists and token scope includes repo write.'
        exit 1
    }
}
