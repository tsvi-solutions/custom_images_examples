<div align="center">

# ◈ Pre-warmed GitHub-hosted runners

### GitHub-managed foundation. Your software. Ready in seconds.

[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-Custom_Images-2088FF?style=for-the-badge&logo=githubactions&logoColor=white&labelColor=0D1117)](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images)
[![Platforms](https://img.shields.io/badge/Platforms-Linux_%C2%B7_Windows_%C2%B7_ARM64-8250DF?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117)](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images)
[![Verified POC](https://img.shields.io/badge/VERIFIED-26.1%C3%97_FASTER-1F883D?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117)](#-one-measured-implementation)
[![Use template](https://img.shields.io/badge/START_HERE-USE_TEMPLATE-238636?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117)](#-use-this-template)

Build the environment once. Stop paying the setup tax on every run.

</div>

---

## ↯ Why custom images

<p align="center">
  <a href="assets/custom-image-value.svg">
    <img src="assets/custom-image-value.svg" width="100%" alt="Without a custom image, every run repeats repository materialization, software installation, and workspace preparation; a warm image captures that setup once to reduce time and runner cost and accelerate feedback">
  </a>
</p>

<table>
<tr>
<td align="center" width="33%"><strong>↯ FASTER</strong><br><sub>REMOVE SETUP</sub></td>
<td align="center" width="33%"><strong>◇ LOWER COST</strong><br><sub>STOP REBUILDING</sub></td>
<td align="center" width="33%"><strong>✓ CONSISTENT</strong><br><sub>START VALIDATED</sub></td>
</tr>
</table>

## ◆ Where they help

<p align="center">
  <a href="assets/prewarming-use-cases.svg">
    <img src="assets/prewarming-use-cases.svg" width="100%" alt="Enterprise, mobile, web, data, machine learning, database, repository, security, and infrastructure workloads that benefit from pre-warmed custom images">
  </a>
</p>

Capture work that is **large, stable, slow, deterministic, and safe**.

[See workload examples, caching guidance, and architecture →](docs/deep-dive.md)

## ✓ One measured implementation

**Windows + SQL Server + full-history LLVM workspace**

| Ready for work | Standard runner | Custom image |
|---|---:|---:|
| Measured time | 12 min 06 sec | **28 sec** |

<table>
<tr>
<td align="center" width="33%"><strong>698.54 sec</strong><br><sub>REMOVED</sub></td>
<td align="center" width="33%"><strong>96.2%</strong><br><sub>REDUCTION</sub></td>
<td align="center" width="33%"><strong>26.1×</strong><br><sub>FASTER</sub></td>
</tr>
</table>

| Runs / month | Standard Windows | Custom image* |
|---:|---:|---:|
| 1,000 | $130.00 | **$26.67** |
| 10,000 | $1,300.00 | **$224.67** |
| 50,000 | $6,500.00 | **$1,104.67** |

<sub>
* Example runner compute using this POC. Storage and plan allowances vary.
</sub>

Both paths used fresh hosted VMs, the same commit, the same 186,978 files, and
the same Git-to-SQL proof.

[Review exact timings, assumptions, and correctness evidence →](docs/deep-dive.md#verified-benchmark-evidence)

## ⌘ Use this template

<p align="center">
  <a href="assets/template-journey.svg">
    <img src="assets/template-journey.svg" width="100%" alt="Configure, build, consume, and prove the custom-image template">
  </a>
</p>

1. Configure image-generation and consumer runners.
2. Set `BENCHMARK_REPOSITORY`.
3. Build the image and publish your own before/after result.

[Build image](.github/workflows/build-custom-image.yml)
· [Run benchmark](.github/workflows/compare-before-after.yml)
· [Validate daily](.github/workflows/validate-custom-image.yml)

---

<div align="center">

**[Implementation, lifecycle, security, economics, and references →](docs/deep-dive.md)**

[GitHub custom-image documentation](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/larger-runners/use-custom-images)
· [Community examples](https://github.com/km-allthethings/build-custom-images)

</div>
