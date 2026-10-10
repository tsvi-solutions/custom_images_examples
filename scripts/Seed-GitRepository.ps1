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
$repositoryUrlPath = Join-Path $CacheRoot "repository-url.txt"
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
if (Test-Path -LiteralPath $mirrorPath) {
    Remove-Item -LiteralPath $mirrorPath -Recurse -Force
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

Set-Content `
    -LiteralPath $repositoryUrlPath `
    -Value $normalizedRemoteUrl `
    -Encoding utf8 `
    -NoNewline

Write-Host "Seeded credential-free mirror at '$mirrorPath'."
