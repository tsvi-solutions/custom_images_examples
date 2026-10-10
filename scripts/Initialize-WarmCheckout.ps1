[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$WorkspacePath,

    [Parameter(Mandatory)]
    [string]$RemoteUrl,

    [string]$CacheRoot = "C:\ProgramData\GitHubCustomImage"
)

$ErrorActionPreference = "Stop"
$mirrorPath = Join-Path $CacheRoot "repository.git"
$preparedWorktreePath = Join-Path $CacheRoot "worktree"
$repositoryUrlPath = Join-Path $CacheRoot "repository-url.txt"
$normalizedRemoteUrl = $RemoteUrl.TrimEnd("/")
if ($normalizedRemoteUrl.EndsWith(".git", [StringComparison]::OrdinalIgnoreCase)) {
    $normalizedRemoteUrl = $normalizedRemoteUrl.Substring(
        0,
        $normalizedRemoteUrl.Length - 4
    )
}
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

if (-not (Test-Path -LiteralPath (Join-Path $mirrorPath "HEAD"))) {
    throw "The custom image does not contain the repository mirror at '$mirrorPath'."
}

if (-not (Test-Path -LiteralPath $repositoryUrlPath)) {
    throw "The custom image does not identify its cached repository. Rebuild the image."
}

$cachedRemoteUrl = (Get-Content -LiteralPath $repositoryUrlPath -Raw).Trim().TrimEnd("/")
if ($cachedRemoteUrl.EndsWith(".git", [StringComparison]::OrdinalIgnoreCase)) {
    $cachedRemoteUrl = $cachedRemoteUrl.Substring(0, $cachedRemoteUrl.Length - 4)
}
if (-not $cachedRemoteUrl.Equals(
    $normalizedRemoteUrl,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "The image caches '$cachedRemoteUrl', not '$normalizedRemoteUrl'. Rebuild the image after changing BENCHMARK_REPOSITORY."
}

$workspaceParent = Split-Path -Parent $WorkspacePath
New-Item -ItemType Directory -Path $workspaceParent -Force | Out-Null

if (Test-Path -LiteralPath $WorkspacePath) {
    $existingEntries = @(Get-ChildItem -LiteralPath $WorkspacePath -Force)
    if ($existingEntries.Count -ne 0) {
        throw "The runner workspace must be empty before the warm checkout is initialized."
    }
    [System.IO.Directory]::Delete($WorkspacePath, $false)
}

$preparedGitPath = Join-Path $preparedWorktreePath ".git"
if (-not (Test-Path -LiteralPath $preparedGitPath)) {
    throw "The custom image does not contain a prepared worktree at '$preparedWorktreePath'. Rebuild the image and configure the consumer runner to use Latest."
}

$sourceRoot = [System.IO.Path]::GetPathRoot(
    [System.IO.Path]::GetFullPath($preparedWorktreePath)
)
$destinationRoot = [System.IO.Path]::GetPathRoot(
    [System.IO.Path]::GetFullPath($WorkspacePath)
)
if (-not $sourceRoot.Equals(
    $destinationRoot,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "The prepared worktree and runner workspace must be on the same volume."
}

[System.IO.Directory]::Move($preparedWorktreePath, $WorkspacePath)
Write-Host "Activated the image's fully materialized worktree."

& git -C $WorkspacePath remote set-url origin $normalizedRemoteUrl
if ($LASTEXITCODE -ne 0) {
    throw "Unable to configure the repository remote."
}

$stopwatch.Stop()
$stopwatch.Elapsed.TotalSeconds.ToString(
    "0.00",
    [Globalization.CultureInfo]::InvariantCulture
)
