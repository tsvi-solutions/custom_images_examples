[CmdletBinding()]
param(
    [string]$InstallerUrl = "https://go.microsoft.com/fwlink/?linkid=2215158",
    [string]$InstanceName = "MSSQLSERVER"
)

$ErrorActionPreference = "Stop"
$serviceName = if ($InstanceName -eq "MSSQLSERVER") {
    "MSSQLSERVER"
} else {
    "MSSQL`$$InstanceName"
}

function Invoke-ProcessWithHeartbeat {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory)]
        [string]$Activity
    )

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -PassThru `
        -NoNewWindow
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    while (-not $process.WaitForExit(30000)) {
        Write-Host "$Activity is still running ($([math]::Round($timer.Elapsed.TotalMinutes, 1)) minutes elapsed)."
    }

    $timer.Stop()
    Write-Host "$Activity completed in $([math]::Round($timer.Elapsed.TotalMinutes, 1)) minutes."
    return $process.ExitCode
}

if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    Write-Host "SQL Server instance '$InstanceName' is already installed."
    Set-Service -Name $serviceName -StartupType Automatic
    Start-Service -Name $serviceName
    exit 0
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$administrator = [Security.Principal.WindowsBuiltInRole]::Administrator
if (-not $principal.IsInRole($administrator)) {
    throw "SQL Server installation requires an elevated Windows runner."
}

$installerPath = Join-Path $env:RUNNER_TEMP "SQL2022-SSEI-Dev.exe"
$mediaPath = Join-Path $env:RUNNER_TEMP "SQL2022Media"

try {
    Write-Host "Downloading the official SQL Server 2022 Developer installer."
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerPath -UseBasicParsing

    New-Item -ItemType Directory -Path $mediaPath -Force | Out-Null
    $downloadArguments = @(
        "/ACTION=Download"
        "/MEDIAPATH=$mediaPath"
        "/MEDIATYPE=Cab"
        "/QUIET"
    )
    $downloadExitCode = Invoke-ProcessWithHeartbeat `
        -FilePath $installerPath `
        -ArgumentList $downloadArguments `
        -Activity "SQL Server media download"

    if ($downloadExitCode -ne 0) {
        throw "SQL Server media download failed with exit code $downloadExitCode."
    }

    $setup = Get-ChildItem `
        -LiteralPath $mediaPath `
        -Filter setup.exe `
        -Recurse |
        Select-Object -First 1
    if (-not $setup) {
        throw "The SQL Server media download did not produce setup.exe."
    }

    $setupArguments = @(
        "/Q"
        "/ACTION=Install"
        "/FEATURES=SQLEngine"
        "/INSTANCENAME=$InstanceName"
        '/SQLSVCACCOUNT="NT AUTHORITY\SYSTEM"'
        "/SQLSVCSTARTUPTYPE=Automatic"
        '/SQLSYSADMINACCOUNTS="BUILTIN\Administrators"'
        "/TCPENABLED=1"
        "/NPENABLED=0"
        "/UpdateEnabled=False"
        "/SUPPRESSPRIVACYSTATEMENTNOTICE"
        "/IACCEPTSQLSERVERLICENSETERMS"
    )

    $setupExitCode = Invoke-ProcessWithHeartbeat `
        -FilePath $setup.FullName `
        -ArgumentList $setupArguments `
        -Activity "SQL Server setup"

    if ($setupExitCode -notin 0, 3010) {
        $summaryPath = Get-ChildItem `
            -Path "C:\Program Files\Microsoft SQL Server" `
            -Filter Summary.txt `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($summaryPath) {
            Write-Error (Get-Content -LiteralPath $summaryPath.FullName -Raw)
        }
        throw "SQL Server installer failed with exit code $setupExitCode."
    }

    Set-Service -Name $serviceName -StartupType Automatic
    Start-Service -Name $serviceName
    Write-Host "SQL Server Developer installed successfully."
} finally {
    Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $mediaPath -Recurse -Force -ErrorAction SilentlyContinue
}
