[CmdletBinding()]
param(
    [string]$InstallerUrl = "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLServer2022-DEV-x64-ENU.exe",
    [string]$PayloadUrl = "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLServer2022-DEV-x64-ENU.box",
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
        [string]$Activity,

        [Parameter(Mandatory)]
        [int]$TimeoutMinutes
    )

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -PassThru `
        -NoNewWindow
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    while (-not $process.WaitForExit(30000)) {
        Write-Host "$Activity is still running ($([math]::Round($timer.Elapsed.TotalMinutes, 1)) minutes elapsed)."
        if ($timer.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
            & taskkill.exe /PID $process.Id /T /F 2>&1 |
                ForEach-Object { Write-Host $_ }
            throw "$Activity exceeded its $TimeoutMinutes-minute timeout."
        }
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

$installerPath = Join-Path $env:RUNNER_TEMP "SQLServer2022-DEV-x64-ENU.exe"
$payloadPath = Join-Path $env:RUNNER_TEMP "SQLServer2022-DEV-x64-ENU.box"
$mediaPath = Join-Path $env:RUNNER_TEMP "SQL2022Media"

try {
    Write-Host "Downloading official SQL Server 2022 Developer media."
    foreach ($download in @(
        @{ Url = $InstallerUrl; Path = $installerPath; Name = "installer" }
        @{ Url = $PayloadUrl; Path = $payloadPath; Name = "payload" }
    )) {
        $downloadExitCode = Invoke-ProcessWithHeartbeat `
            -FilePath "curl.exe" `
            -ArgumentList @(
                "--fail"
                "--location"
                "--retry", "3"
                "--retry-all-errors"
                "--output", $download.Path
                $download.Url
            ) `
            -Activity "SQL Server $($download.Name) download" `
            -TimeoutMinutes 30
        if ($downloadExitCode -ne 0) {
            throw "SQL Server $($download.Name) download failed with exit code $downloadExitCode."
        }
    }

    New-Item -ItemType Directory -Path $mediaPath -Force | Out-Null
    $extractExitCode = Invoke-ProcessWithHeartbeat `
        -FilePath $installerPath `
        -ArgumentList @("/qs", "/x:$mediaPath") `
        -Activity "SQL Server media extraction" `
        -TimeoutMinutes 20
    if ($extractExitCode -ne 0) {
        throw "SQL Server media extraction failed with exit code $extractExitCode."
    }

    $setupPath = Join-Path $mediaPath "setup.exe"
    if (-not (Test-Path -LiteralPath $setupPath)) {
        throw "SQL Server media extraction did not produce setup.exe."
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
        -FilePath $setupPath `
        -ArgumentList $setupArguments `
        -Activity "SQL Server setup" `
        -TimeoutMinutes 45

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
    Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $mediaPath -Recurse -Force -ErrorAction SilentlyContinue
}
