[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryPath,

    [Parameter(Mandatory)]
    [ValidateSet("Before", "After")]
    [string]$Scenario,

    [Parameter(Mandatory)]
    [double]$ReadySeconds
)

$ErrorActionPreference = "Stop"

$commitSha = (& git -C $RepositoryPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $commitSha) {
    throw "Unable to read the benchmark repository commit."
}

$trackedFiles = @(& git -C $RepositoryPath ls-files).Count
if ($LASTEXITCODE -ne 0 -or $trackedFiles -le 0) {
    throw "Unable to enumerate tracked files in the benchmark repository."
}

$connectionString = "Server=localhost;Database=CustomImageExample;Integrated Security=True;Encrypt=False;Connection Timeout=5"
$connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)

try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = @"
IF OBJECT_ID(N'dbo.RunnerReadinessEvidence', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RunnerReadinessEvidence
    (
        EvidenceId int IDENTITY(1,1) PRIMARY KEY,
        Scenario nvarchar(16) NOT NULL,
        CommitSha char(40) NOT NULL,
        TrackedFiles int NOT NULL,
        ReadySeconds decimal(12,2) NOT NULL,
        RecordedAtUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END;

INSERT dbo.RunnerReadinessEvidence
    (Scenario, CommitSha, TrackedFiles, ReadySeconds)
OUTPUT
    inserted.Scenario,
    inserted.CommitSha,
    inserted.TrackedFiles,
    inserted.ReadySeconds
VALUES
    (@Scenario, @CommitSha, @TrackedFiles, @ReadySeconds);
"@
    $command.Parameters.Add("@Scenario", [Data.SqlDbType]::NVarChar, 16).Value = $Scenario
    $command.Parameters.Add("@CommitSha", [Data.SqlDbType]::Char, 40).Value = $commitSha
    $command.Parameters.Add("@TrackedFiles", [Data.SqlDbType]::Int).Value = $trackedFiles
    $readyParameter = $command.Parameters.Add(
        "@ReadySeconds",
        [Data.SqlDbType]::Decimal
    )
    $readyParameter.Precision = 12
    $readyParameter.Scale = 2
    $readyParameter.Value = $ReadySeconds

    $reader = $command.ExecuteReader()
    if (-not $reader.Read()) {
        throw "SQL Server did not return the inserted readiness evidence."
    }

    [PSCustomObject]@{
        Scenario = [string]$reader["Scenario"]
        CommitSha = [string]$reader["CommitSha"]
        TrackedFiles = [int]$reader["TrackedFiles"]
        ReadySeconds = [decimal]$reader["ReadySeconds"]
    }
} finally {
    $connection.Dispose()
}

