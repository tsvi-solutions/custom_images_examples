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
$repositoryUrlPath = Join-Path $CacheRoot "repository-url.txt"
$normalizedRemoteUrl = $RemoteUrl.TrimEnd("/")
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

if (-not (Test-Path -LiteralPath (Join-Path $mirrorPath "HEAD"))) {
    throw "The custom image does not contain the repository mirror at '$mirrorPath'."
}

if (-not (Test-Path -LiteralPath $repositoryUrlPath)) {
    throw "The custom image does not identify its cached repository. Rebuild the image."
}

$cachedRemoteUrl = (Get-Content -LiteralPath $repositoryUrlPath -Raw).Trim().TrimEnd("/")
if (-not $cachedRemoteUrl.Equals(
    $normalizedRemoteUrl,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "The image caches '$cachedRemoteUrl', not '$normalizedRemoteUrl'. Rebuild the image after changing BENCHMARK_REPOSITORY."
}

New-Item -ItemType Directory -Path $WorkspacePath -Force | Out-Null
$existingEntries = @(Get-ChildItem -LiteralPath $WorkspacePath -Force)
if ($existingEntries.Count -ne 0) {
    throw "The runner workspace must be empty before the warm checkout is initialized."
}

& git clone --reference-if-able $mirrorPath --no-checkout $mirrorPath $WorkspacePath
if ($LASTEXITCODE -ne 0) {
    throw "Unable to initialize the workspace from the image cache."
}

& git -C $WorkspacePath remote set-url origin $normalizedRemoteUrl
if ($LASTEXITCODE -ne 0) {
    throw "Unable to configure the repository remote."
}

$stopwatch.Stop()
$stopwatch.Elapsed.TotalSeconds.ToString(
    "0.00",
    [Globalization.CultureInfo]::InvariantCulture
)
