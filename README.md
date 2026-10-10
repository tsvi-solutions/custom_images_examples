<div align="center">

# 🚀 GitHub Actions Custom Images

### Turn slow, repetitive runner setup into a fast, ready-to-work environment

[![Platform](https://img.shields.io/badge/platform-Windows%20x64-0078D4?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/actions/runner-images)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-Custom_Images-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images)
[![SQL Server](https://img.shields.io/badge/SQL_Server-2022_Developer-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)](https://learn.microsoft.com/sql/database-engine/install-windows/install-sql-server)
[![Powered by](https://img.shields.io/badge/powered_by-snapshot-8250DF?style=for-the-badge&logo=github&logoColor=white)](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images)

**Example 01 · Large monorepo checkout + preinstalled SQL Server**

[See the architecture](#-the-big-idea) ·
[Run the demo](#-run-the-demo) ·
[Understand the results](#-what-the-benchmark-measures)

</div>

---

## ✨ Why custom images?

Every minute spent rebuilding the same environment is a minute that every
workflow run—and every developer waiting on it—pays again.

| Without a custom image | With a custom image |
|---|---|
| 📥 Download the complete Git history | ⚡ Reuse Git objects already on disk |
| 📦 Download SQL Server installation media | ✅ SQL Server is already installed |
| 🛠️ Run unattended installation and configuration | 🟢 Start the service and query it |
| ⏳ Repeat the work in every job | 🎯 Fetch only changes since the image build |
| 🌐 Depend heavily on network throughput | 💾 Shift stable dependencies to the image |

> [!TIP]
> The value is not merely “a faster VM.” A custom image removes deterministic,
> repeated setup work from the critical path of every job.

## 🎯 The centerpiece: before vs. after

This example compares two jobs that produce the **same outcome**:

- a complete Git checkout with full history; and
- a running SQL Server instance containing an empty `CustomImageExample`
  database.

```mermaid
flowchart LR
    Trigger([▶ Run benchmark])

    subgraph Before["BEFORE · Standard windows-latest"]
        direction TB
        B1["📥 Download full Git history"]
        B2["📦 Download SQL Server media"]
        B3["🛠️ Install + configure SQL Server"]
        B4["🗄️ Create example database"]
        B1 --> B2 --> B3 --> B4
    end

    subgraph Image["CUSTOM IMAGE · Built weekly"]
        direction TB
        I1["🪞 Credential-free Git mirror"]
        I2["🗄️ SQL Server 2022 Developer"]
        I3["📸 GitHub snapshot"]
        I1 --> I3
        I2 --> I3
    end

    subgraph After["AFTER · Custom-image runner"]
        direction TB
        A1["⚡ Clone from local mirror"]
        A2["🔄 Fetch only the Git delta"]
        A3["✅ Query preinstalled SQL Server"]
        A4["🗄️ Create example database"]
        A1 --> A2 --> A3 --> A4
    end

    Result["📊 Compare checkout, SQL, total time + speedup"]

    Trigger --> Before
    Trigger --> After
    Image -. "pre-warms" .-> After
    Before --> Result
    After --> Result

    classDef trigger fill:#24292f,color:#ffffff,stroke:#57606a,stroke-width:2px;
    classDef slow fill:#ffebe9,color:#82071e,stroke:#cf222e,stroke-width:2px;
    classDef image fill:#fbefff,color:#5a1e75,stroke:#8250df,stroke-width:2px;
    classDef fast fill:#dafbe1,color:#116329,stroke:#1a7f37,stroke-width:2px;
    classDef result fill:#ddf4ff,color:#0550ae,stroke:#0969da,stroke-width:3px;

    class Trigger trigger;
    class B1,B2,B3,B4 slow;
    class I1,I2,I3 image;
    class A1,A2,A3,A4 fast;
    class Result result;
```

### ✅ Verified result

The first validated comparison ran against `llvm/llvm-project` at commit
`d7b282cbfe7b8e6653beaf9159b2f8ce888cedaa` with **186,973 tracked files**:

| Measurement | 🔴 Before: `windows-latest` | 🟢 After: custom image | Improvement |
|---|---:|---:|---:|
| Full-history checkout | 9 min 31 sec | 3 min 27 sec | 6 min 04 sec saved |
| SQL Server setup/readiness | 2 min 54 sec | 0 min 0.59 sec | 2 min 54 sec saved |
| **Ready to execute dependent commands** | **12 min 26 sec** | **3 min 28 sec** | **8 min 58 sec saved** |
| Git + SQL proof workload | 0 min 0.80 sec | 0 min 0.42 sec | Both passed |

> **72.1% less setup time · 3.6× faster to a usable runner**

[View the successful benchmark run →](https://github.com/tsvi-solutions/custom_images_examples/actions/runs/38059867565)

The warm checkout still materializes the requested working tree—nearly 187,000
files in this run—but it reuses the image's Git object store. The validated log
contains no `Deleting the contents` event, proving that `actions/checkout`
preserved the pre-seeded clone.

The benchmark does **not** inflate this example repository with generated
files. By default, it performs a real full-history checkout of
[`llvm/llvm-project`](https://github.com/llvm/llvm-project), a substantial
public monorepo. Set the `BENCHMARK_REPOSITORY` repository or organization
variable to use a different `owner/repository`, including your own
representative monorepo.

Actual numbers depend on repository size, repository growth, image freshness,
runner size, and network conditions. The workflow reports real measurements
instead of promising a synthetic “5-minute to 5-second” result.

## 🧠 The big idea

The image-generation workflow checks out the selected benchmark monorepo once
and creates a sanitized bare mirror:

```text
C:\ProgramData\GitHubCustomImage\repository.git
```

The consumer job creates a no-checkout clone backed by that local object store.
It then hands control to `actions/checkout`, which authenticates normally and
fetches the exact branch, tag, or pull-request SHA requested by the event.
The bootstrap script normalizes the origin URL to the exact format expected by
`actions/checkout`, preventing its repository-safety check from discarding the
pre-seeded clone.

```mermaid
sequenceDiagram
    autonumber
    participant Build as Image build
    participant Mirror as Local Git mirror
    participant Snapshot as Custom image
    participant Job as Workflow job
    participant GitHub as Benchmark monorepo

    Note over Build,Snapshot: IMAGE BUILD · prepare once
    Build->>GitHub: Full-history checkout
    Build->>Mirror: Create credential-free bare mirror
    Build->>Build: Install and validate SQL Server
    Build->>Snapshot: Capture with native snapshot keyword

    Note over Snapshot,GitHub: WORKFLOW JOB · reuse on every run
    Snapshot-->>Job: Start pre-warmed runner
    Job->>Mirror: Create local reference clone
    Job->>GitHub: Fetch only missing objects and requested ref
    Job->>Job: Query preinstalled SQL Server
```

### Why this strategy?

| Benefit | How this example delivers it |
|---|---|
| ⚡ **Fast checkout** | Existing Git objects are read from the image; only the delta crosses the network |
| 🔐 **No baked credentials** | The build uses `persist-credentials: false` and rejects auth headers or token markers |
| 🎯 **Correct revision** | `actions/checkout` still resolves and checks out the event’s requested SHA |
| 🍴 **Fork-friendly** | Runtime authentication remains read-only and scoped to the workflow job |
| 🔁 **Repeatable** | A weekly image build refreshes Git history, Windows patches, and SQL media |
| 📏 **Measurable** | Equivalent before/after jobs publish an automated comparison table |

## 🏃 Run the demo

### 1 · Create the image-generation runner

Custom images are available for **GitHub-hosted larger runners**. The custom
image can start from GitHub’s `windows-latest` image, but it is consumed through
a named larger runner—not through the standard `windows-latest` label.

> [!IMPORTANT]
> This is the bootstrap step—**you do not need an existing custom image**.
> Create the image-generation runner from GitHub's standard `windows-latest`
> base image. The runner executes the image-build workflow, and the workflow's
> `snapshot` keyword publishes your first custom image.

> [!WARNING]
> Create this runner from **organization settings**, not repository settings.
> Repository **Settings → Actions → Runners** only offers self-hosted runners.
> GitHub-hosted larger runners require a **GitHub Team** or
> **GitHub Enterprise Cloud** organization plan. Custom images cannot be built
> with a standard `windows-latest` job or a self-hosted runner.

```mermaid
flowchart LR
    Base["GitHub-owned<br/>windows-latest"]
    Builder["Image-generation<br/>larger runner"]
    Workflow["Build Windows<br/>monorepo image"]
    First["First custom image<br/>windows-monorepo-sqlserver"]

    Base -->|"create runner"| Builder
    Builder -->|"runs workflow"| Workflow
    Workflow -->|"snapshot"| First

    classDef base fill:#ddf4ff,color:#0550ae,stroke:#0969da,stroke-width:2px;
    classDef builder fill:#fff8c5,color:#633c01,stroke:#bf8700,stroke-width:2px;
    classDef workflow fill:#fbefff,color:#5a1e75,stroke:#8250df,stroke-width:2px;
    classDef image fill:#dafbe1,color:#116329,stroke:#1a7f37,stroke-width:3px;

    class Base base;
    class Builder builder;
    class Workflow workflow;
    class First image;
```

1. Open the organization runner page:
   `https://github.com/organizations/YOUR-ORGANIZATION/settings/actions/runners`.
   For this repository, use
   `https://github.com/organizations/tsvi-solutions/settings/actions/runners`.
2. Click **New runner → New GitHub-hosted runner**. If that choice is absent,
   verify that you are an organization owner and that the organization uses
   GitHub Team or GitHub Enterprise Cloud.
3. Enable custom images in the organization or enterprise Actions policy.
4. Create the GitHub-hosted larger runner with:
   - **Platform:** Windows x64
   - **Base image:** GitHub-owned `windows-latest`
   - **Generate custom images:** enabled
   - **Runner group:** one that can access this repository
5. Name it `windows-image-generation`, or set the organization variable
   `IMAGE_GENERATION_RUNNER` to the actual runner name.
6. Optionally set `BENCHMARK_REPOSITORY` to an `owner/repository`. It defaults
   to `llvm/llvm-project`.
7. Run **Build Windows monorepo image** from the Actions tab.

The [image workflow](.github/workflows/build-custom-image.yml) installs and
validates SQL Server, creates and verifies the Git mirror, checks for captured
credentials, and publishes `windows-monorepo-sqlserver` only after every step
succeeds.

### Benchmark repository configuration

| Setting | Required | Purpose |
|---|:---:|---|
| `BENCHMARK_REPOSITORY` Actions variable | No | Repository to clone; defaults to `llvm/llvm-project` |
| `BENCHMARK_TOKEN` Actions secret | Private repositories only | Fine-grained token with read-only Contents access to the benchmark repository |

The image records the benchmark repository URL next to the mirror. If
`BENCHMARK_REPOSITORY` changes without rebuilding the image, the after job
fails with a clear mismatch message instead of publishing an invalid
comparison. Run **Build Windows monorepo image** again after changing it.

The token is used only by `actions/checkout`. The benchmark checkout sets
`persist-credentials: false`, the mirror stores only a plain HTTPS remote, and
the image build scans the Git configuration before creating the snapshot.

> [!NOTE]
> GitHub may continue provisioning the image after the workflow completes.
> Each successful run creates a new image version and consumes Actions storage.

### 2 · Create the custom-image runner

> [!IMPORTANT]
> Publishing a custom image does **not** create a runner that uses it. Create a
> second GitHub-hosted larger runner and select the new custom image. The
> image-generation runner cannot pick up consumer jobs because it has a
> different label and still uses the GitHub-owned base image.

1. Create another GitHub-hosted larger runner.
2. Choose **Windows x64**.
3. On the **Custom** image tab, select `windows-monorepo-sqlserver` version
   `1.0.0` (or the latest ready version).
4. Choose **4 cores, 16 GB RAM, 150 GB SSD** and maximum concurrency **1**.
5. Use the same runner group as the image-generation runner.
6. Name it `windows-monorepo-sqlserver-runner`, or set
   `CUSTOM_IMAGE_RUNNER` to the actual runner name.

### 3 · Run the comparison

Open **Actions → Compare before and after custom image → Run workflow**.

The [comparison workflow](.github/workflows/compare-before-after.yml) starts the
cold and pre-warmed jobs in parallel, then publishes:

```text
checkout duration
SQL Server installation/readiness duration
total measured setup duration
seconds saved
percentage reduction
overall speedup
full visual step-by-step timing breakdown
premium GitHub Actions summary with metric cards and Mermaid charts
```

At the end of both paths, the workflow runs the same dependent workload:

```powershell
git -C benchmark-source rev-parse HEAD
git -C benchmark-source ls-files
# Insert the commit, file count, scenario, and time-to-ready into SQL Server,
# then query the inserted row back.
./scripts/Invoke-ExampleWorkload.ps1
```

The benchmark commit is resolved once and pinned for both jobs. The comparison
fails if their commit SHA or tracked-file count differs. The final summary
therefore proves not only that setup completed, but that both runners were
ready to execute commands depending on **both** the monorepo and SQL Server
after the reported number of minutes.

The lightweight checkout of this example repository supplies only the
PowerShell tooling and occurs **before** timing starts. The measured checkout is
the separate benchmark monorepo:

- **Before:** `actions/checkout` downloads its complete history from GitHub.
- **After:** a local reference clone reuses the mirror baked into the image,
  then `actions/checkout` downloads only objects added since the image build.

Both timers begin in the first measured step. Runner queue and provisioning
time are excluded because those values reflect runner capacity and service
conditions—not setup work removed by the image.

## 📊 Optional: see what the runners are doing

Enable the **Collect CPU, memory, disk, network, and process telemetry** option
when dispatching the comparison workflow to add
[Runner Telemetry Action](https://github.com/marketplace/actions/runner-telemetry-action)
reports to both jobs.

Telemetry complements the timing table:

- **network and disk I/O** make the cold clone versus local mirror visible;
- **top processes** show SQL Server setup activity on the baseline;
- **CPU and memory** help distinguish image benefits from runner-sizing issues;
- **per-job reports** provide evidence for both the before and after paths.

It is disabled by default so the core benchmark stays minimal. When enabled,
the action starts **before** the measured region and stops **after** it, so its
setup and report-generation overhead are excluded from the comparison. The
workflow pins the action to the commit currently referenced by the `v1` tag rather than
executing a mutable tag directly.

## 📁 Explore the implementation

| File | Role |
|---|---|
| [`.github/workflows/build-custom-image.yml`](.github/workflows/build-custom-image.yml) | Builds, validates, versions, and snapshots the Windows image |
| [`.github/workflows/compare-before-after.yml`](.github/workflows/compare-before-after.yml) | Clones a real external monorepo, runs the fair before/after benchmark, and publishes results |
| [`scripts/Install-SqlServer.ps1`](scripts/Install-SqlServer.ps1) | Downloads official media and installs SQL Server 2022 Developer silently |
| [`scripts/Seed-GitRepository.ps1`](scripts/Seed-GitRepository.ps1) | Builds and sanitizes the bare repository mirror |
| [`scripts/Initialize-WarmCheckout.ps1`](scripts/Initialize-WarmCheckout.ps1) | Creates the local reference clone before `actions/checkout` |
| [`scripts/Test-SqlServer.ps1`](scripts/Test-SqlServer.ps1) | Waits for SQL Server, runs a query, and optionally creates the demo database |
| [`scripts/Invoke-ExampleWorkload.ps1`](scripts/Invoke-ExampleWorkload.ps1) | Reads the pinned Git revision and records/query-verifies it in SQL Server |

## 🛡️ Security and operational guardrails

> [!CAUTION]
> Never bake secrets, access tokens, production data, or long-lived
> credentials into a custom image.

- **No credentials are captured.** The mirror uses a plain HTTPS origin, and
  the build fails if it detects an authentication header or token marker.
- **Secrets arrive at runtime.** `actions/checkout` uses the job’s short-lived
  `GITHUB_TOKEN`.
- **Image freshness matters.** The build runs weekly, following GitHub’s
  recommendation; increase the cadence for high-churn monorepos.
- **Storage is not free.** Every successful snapshot creates an image version.
  Configure an appropriate custom-image retention policy.
- **SQL Server Developer is for development and CI.** Review Microsoft’s terms
  and choose a properly licensed edition for other uses.
- **Test data stays disposable.** The benchmark creates its database at job
  runtime rather than capturing mutable data in the image.

## 🗺️ More examples are coming

This repository is designed as a growing gallery. Each future example will
answer the same three questions:

1. **What repeated work is slowing jobs down?**
2. **What belongs safely in a reusable image?**
3. **How much faster is the measured before/after result?**

| Example | Use case | Status |
|---:|---|:---:|
| **01** | Windows monorepo checkout + SQL Server | 🟢 Available |
| **02** | Coming next | ⚪ Planned |
| **03** | Coming next | ⚪ Planned |

---

## 📚 References

- [Using custom images for GitHub-hosted larger runners](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images)
- [Runner Telemetry Action](https://github.com/marketplace/actions/runner-telemetry-action)
- [SQL Server unattended installation](https://learn.microsoft.com/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt)
- [Community custom-image examples](https://github.com/km-allthethings/build-custom-images)

<div align="center">

### Build once · Validate once · Start every job ready

</div>
