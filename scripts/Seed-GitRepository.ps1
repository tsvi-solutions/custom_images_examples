[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [string]$CacheRoot,

    [Parameter(Mandatory)]
    [string]$RemoteUrl
)

$ErrorActionPreference = "Stop"
$mirrorPath = Join-Path $CacheRoot "repository.git"
$worktreePath = Join-Path $CacheRoot "worktree"
$repositoryUrlPath = Join-Path $CacheRoot "repository-url.txt"
$cachedCommitPath = Join-Path $CacheRoot "cached-commit.txt"
$normalizedRemoteUrl = $RemoteUrl.TrimEnd("/")
if ($normalizedRemoteUrl.EndsWith(".git", [StringComparison]::OrdinalIgnoreCase)) {
    $normalizedRemoteUrl = $normalizedRemoteUrl.Substring(
        0,
        $normalizedRemoteUrl.Length - 4
    )
}

if (-not (Test-Path -LiteralPath (Join-Path $SourcePath ".git"))) {
    throw "'$SourcePath' is not a Git working tree."
}

New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
foreach ($path in @($mirrorPath, $worktreePath)) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

& git clone --mirror $SourcePath $mirrorPath
if ($LASTEXITCODE -ne 0) {
    throw "Unable to create the image's Git mirror."
}

& git -C $mirrorPath remote set-url origin $normalizedRemoteUrl
if ($LASTEXITCODE -ne 0) {
    throw "Unable to sanitize the mirror's origin URL."
}

& git -C $mirrorPath config --unset-all http.https://github.com/.extraheader 2>$null
& git -C $mirrorPath config gc.auto 0
& git -C $mirrorPath fsck --full
if ($LASTEXITCODE -ne 0) {
    throw "The image's Git mirror failed validation."
}

& git clone --reference-if-able $mirrorPath $mirrorPath $worktreePath
if ($LASTEXITCODE -ne 0) {
    throw "Unable to create the image's prepared Git worktree."
}

& git -C $worktreePath remote set-url origin $normalizedRemoteUrl
if ($LASTEXITCODE -ne 0) {
    throw "Unable to sanitize the prepared worktree's origin URL."
}

& git -C $worktreePath config --unset-all http.https://github.com/.extraheader 2>$null
& git -C $worktreePath config gc.auto 0

$cachedCommit = (& git -C $worktreePath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $cachedCommit) {
    throw "Unable to identify the prepared worktree commit."
}

& git -C $worktreePath checkout --detach $cachedCommit
if ($LASTEXITCODE -ne 0) {
    throw "Unable to detach the prepared worktree at '$cachedCommit'."
}

$worktreeStatus = @(& git -C $worktreePath status --porcelain)
if ($LASTEXITCODE -ne 0 -or $worktreeStatus.Count -ne 0) {
    throw "The image's prepared worktree is not clean."
}

Set-Content `
    -LiteralPath $repositoryUrlPath `
    -Value $normalizedRemoteUrl `
    -Encoding utf8 `
    -NoNewline

Set-Content `
    -LiteralPath $cachedCommitPath `
    -Value $cachedCommit `
    -Encoding ascii `
    -NoNewline

Write-Host "Seeded credential-free mirror at '$mirrorPath'."
Write-Host "Prepared worktree at '$worktreePath' on commit $cachedCommit."
