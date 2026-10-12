# Custom-image deep dive

This reference contains the implementation, economics, competitive context,
and operational detail intentionally kept out of the visual
[README](../README.md).

## Workload examples

| Workload | Put in the image | Remove from every job |
|---|---|---|
| **Enterprise toolchains** | Approved compilers, build workloads, internal CA certificates | Long bootstrap scripts and configuration drift |
| **Mobile builds** | Android SDKs, emulator images, device tooling | Large SDK and system-image downloads |
| **Browser testing** | Browser binaries, drivers, stable test assets | Repeated Playwright or browser installation |
| **Databases and services** | SQL engines, clients, local service configuration | Installer downloads, service setup, restarts |
| **Large repositories** | Git mirror, full history, materialized workspace | Multi-GB clone and file materialization |
| **Data and ML builds** | Runtimes, native libraries, approved model tooling | Heavy environment and native dependency setup |
| **Dependency-heavy builds** | Restored package stores and immutable build dependencies | Re-downloading stable packages on every run |
| **Embedded and IoT** | Cross-compilers, board SDKs, emulators, firmware tools | Rebuilding specialized device environments |
| **Game and graphics builds** | Engine SDKs, content tools, platform workloads | Large editor, SDK, and asset-tool installation |
| **Security and compliance** | Approved scanners, SBOM tools, policy bundles | Installing and aligning security tooling in every job |
| **Infrastructure delivery** | Pinned cloud CLIs, Terraform providers, Helm plugins | Re-fetching approved deployment toolchains |
| **Documentation and localization** | TeX distributions, fonts, converters, language packs | Large document-tool and font installation |
| **Media processing** | Approved codecs, media tools, stable test media | Native package setup and repeated asset downloads |
| **Legacy modernization** | Compatibility SDKs, older runtimes, MSBuild workloads | Reconstructing fragile legacy environments |

The best candidates are large, stable, deterministic, and safe to capture. If
a workflow installs several slow components, one custom image can remove all
of those setup paths.

### Custom image, dependency cache, or artifact?

| Layer | Use it for | Expected behavior |
|---|---|---|
| **Custom image** | OS-level tools, SDKs, services, large stable assets, and validated configuration | Every runner starts with the same versioned foundation |
| **Dependency cache** | Package stores, intermediate outputs, and expensive but regenerable files | A key may hit or miss; the job must work after a miss |
| **Artifact** | Binaries, results, logs, screenshots, and cross-job data | Preserve or share workflow-produced outputs |

1. Put large, stable, slow-to-install software in the custom image.
2. Cache frequently changing, regenerable dependencies with keys derived from
   the OS, tool version, and lockfile.
3. Use restore keys only when a broader partial match is safe.
4. Measure cache transfer time; do not cache data that is faster to regenerate.
5. Upload final outputs and diagnostics as artifacts, not caches.

Treat restored cache contents as untrusted input. Never cache secrets or
sensitive data.

Official guidance:

- [Dependency caching concepts](https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching)
- [Dependency caching and secure use](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)
- [Workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)

## Architecture and competitive context

Custom images optimize **where work starts**. A graph-aware build system
optimizes **what work runs**. GitHub Actions orchestrates, proves, and reports
the result.

| Platform | Particularly strong when | Tradeoff or GitHub Actions response |
|---|---|---|
| **Buildkite** | You want self-hosted agents and runtime-generated pipeline steps. | Your team operates agent infrastructure. GitHub larger runners and custom images preserve managed execution. |
| **CircleCI** | Historical timings should automatically split tests across containers. | GitHub matrices provide parallelism; timing-aware distribution typically comes from another tool. |
| **TeamCity** | Complex chains benefit from Kotlin DSL and IDE support. | GitHub reusable workflows remain close to checks, permissions, and repository governance. |
| **GitLab CI/CD** | Parent-child pipelines and change rules organize independent repository areas. | GitHub supports path filters, matrices, and reusable workflows; graph-aware execution belongs in the build-system layer. |

Custom images do not eliminate every queueing, test-sharding, pipeline-DSL, or
graph-orchestration concern. Before changing CI platforms, identify whether
the bottleneck is environment readiness, runner capacity, test distribution,
or build-graph selection.

References:

- Buildkite:
  [self-hosted agents](https://buildkite.com/docs/agent/self-hosted) ·
  [dynamic pipelines](https://buildkite.com/docs/pipelines/configure/dynamic-pipelines)
- CircleCI:
  [test splitting and parallelism](https://circleci.com/docs/guides/optimize/parallelism-faster-jobs/)
- TeamCity:
  [Kotlin DSL](https://www.jetbrains.com/help/teamcity/kotlin-dsl.html) ·
  [build-chain dependencies](https://www.jetbrains.com/help/teamcity/configuring-dependencies.html)
- GitLab:
  [child pipelines](https://docs.gitlab.com/ci/pipelines/downstream_pipelines/) ·
  [pipeline architecture](https://docs.gitlab.com/ci/pipelines/pipeline_architectures/)
- Monorepo systems:
  [Nx affected](https://nx.dev/docs/features/ci-features/affected) ·
  [Bazel remote caching](https://bazel.build/remote/caching) ·
  [Turborepo CI](https://turborepo.dev/docs/crafting-your-repository/constructing-ci)

## Cost methodology

```text
monthly runner cost =
  workflow runs
  × billed minutes per run
  × runner rate
  + image-build and validation compute
  + retained image storage
```

This is a runner-compute example, not a forecast of a customer's final invoice.

| 1,000-run example | Calculation | Monthly cost |
|---|---|---:|
| Standard Windows path | 1,000 × 13 billed min × $0.010 | $130.00 |
| Custom-image path | 1,000 × 1 billed min × $0.022 + $4.67 | **$26.67** |

GitHub rounds each job up to a whole billed minute. The observed $4.67/month is
weekly image-build and daily-canary compute spread across all consumer runs.
Included private minutes can reduce standard-runner cost.

Custom-image storage is separate. Apply retained size, duration, and plan
allowances in the [GitHub pricing calculator](https://github.com/pricing/calculator?feature=actions)
or billing dashboard.

References:

- [Actions runner pricing](https://docs.github.com/en/enterprise-cloud@latest/billing/reference/actions-runner-pricing)
- [Custom-image storage billing](https://docs.github.com/en/enterprise-cloud@latest/billing/concepts/product-billing/github-actions#custom-image-storage)

## Verified benchmark evidence

### Identity

| Evidence | Value |
|---|---|
| Source repository | `llvm/llvm-project` |
| Commit | `b1dd93c6af666442840896e0f30c1506e587b6db` |
| Tracked files | 186,978 |
| Custom image | `windows-monorepo-sqlserver` version `1.1.0` |
| Source run | `38083459558` |

### Exact timings

| Phase | Standard runner | Custom image |
|---|---:|---:|
| Activate prepared worktree | — | **0.14 sec** |
| `actions/checkout` | 521.95 sec | **26.73 sec** |
| Complete checkout path | 521.95 sec | **26.87 sec** |
| SQL Server setup/readiness | 203.51 sec | **0.27 sec** |
| **Ready for dependent work** | **726.33 sec** | **27.79 sec** |
| Git-to-SQL proof workload | 1.57 sec | **0.35 sec** |

### Correctness gates

- Both jobs checked out the same pinned commit.
- Both jobs reported the same 186,978 tracked files.
- Both jobs inserted Git evidence into SQL Server and queried it back.
- Both jobs started on fresh GitHub-hosted VMs.
- Queue time, VM provisioning, and the tooling checkout were excluded.

## Implementation guide

Custom images require GitHub-hosted larger runners at organization or
enterprise scope.

### Image-generation runner

Create a Windows x64 GitHub-hosted larger runner:

| Setting | Value |
|---|---|
| Base image | GitHub-owned `windows-latest` |
| Generate custom images | Enabled |
| Name | `windows-image-generation` |

Run **Build Windows monorepo image**. It publishes
`windows-monorepo-sqlserver`.

### Consumer runner

Create a second Windows x64 larger runner:

| Setting | Value |
|---|---|
| Image | Custom → `windows-monorepo-sqlserver` |
| Version | **Latest** |
| Size | 4 cores, 16 GB RAM, 150 GB SSD |
| Name | `windows-monorepo-sqlserver-runner` |

Selecting
[Latest](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images#installing-custom-images)
adopts newly published versions. Pin a version only for rollback.

| Optional setting | Purpose |
|---|---|
| `IMAGE_GENERATION_RUNNER` | Override the image-generation runner name |
| `CUSTOM_IMAGE_RUNNER` | Override the consumer runner name |
| `BENCHMARK_REPOSITORY` | Replace `llvm/llvm-project` |
| `BENCHMARK_TOKEN` | Read-only token for a private repository |
| `CUSTOM_IMAGE_MAX_AGE_DAYS` | Override the 10-day freshness limit |

### Warm Git checkout

The image contains:

```text
C:\ProgramData\GitHubCustomImage\repository.git
C:\ProgramData\GitHubCustomImage\worktree
```

At runtime, `Initialize-WarmCheckout.ps1` moves the prepared worktree into
`GITHUB_WORKSPACE` on the same disk. `actions/checkout` authenticates, fetches
current refs, and force-checks the pinned SHA.

The custom path uses `clean: false` because the image build proves the worktree
is clean and each hosted VM is fresh. A metadata-only detached `HEAD` avoids
rescanning every file. The build uses `persist-credentials: false` and scans
both cached repositories for credential markers before snapshotting.

References:

- [Generating a custom image](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images#generating-a-custom-image)
- [Community examples](https://github.com/km-allthethings/build-custom-images)

## Operations and security

### Promotion, rollback, and retention

- The build publishes incremented `1.*` versions.
- The consumer follows **Latest**.
- For rollback, pin the previous known-good version and run the canary.
- Return to **Latest** after remediation.
- Keep the current image and at least one compatible rollback version.

Do not delete the previous image before the new version passes the consumer
canary. A 14-day retention window is a practical starting point for weekly
builds.

### Guardrails

- Never capture secrets, production data, long-lived credentials, or
  unlicensed software.
- Use a dedicated runner group for image generation.
- Keep workflow permissions read-only where possible.
- Validate software and credential hygiene before snapshotting.
- Start benchmark paths on fresh VMs.
- Resolve one commit, require equal file counts, and execute the same proof.
- Treat setup time as workflow time, not automatically as labor savings.

Official documentation:

- [Using custom images](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images)
- [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Larger runners](https://docs.github.com/en/enterprise-cloud@latest/actions/concepts/runners/larger-runners)
- [Custom-image retention policies](https://docs.github.com/en/enterprise-cloud@latest/admin/enforcing-policies/enforcing-policies-for-your-enterprise/enforcing-policies-for-github-actions-in-your-enterprise#custom-images-retention-policies)
- [Custom-image security guidance](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images#security-best-practices-for-custom-images)
