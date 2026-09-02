# Sanity Test Suite Documentation

The sanity test script (`test/sanity-test.sh`) validates both the **Docker container image** and the **standalone `.tar.gz` archive** to prevent regressions before publishing.

---

## Running the Tests

### Test Docker Image
```bash
./test/sanity-test.sh docker <IMAGE_TAG>
# Example:
./test/sanity-test.sh docker gcloud-lite:latest
```

### Test Release Tarball
```bash
./test/sanity-test.sh tarball <PATH_TO_TAR_GZ>
# Example:
./test/sanity-test.sh tarball ./dist/google-cloud-cli-573.0.0-linux-x86_64-lite.tar.gz
```

### Test Both Simultaneously
```bash
./test/sanity-test.sh all <IMAGE_TAG> <PATH_TO_TAR_GZ>
# Example:
./test/sanity-test.sh all gcloud-lite:latest ./dist/google-cloud-cli-573.0.0-linux-x86_64-lite.tar.gz
```

### Via Makefile
```bash
make sanity-test-docker IMAGE_TAG=gcloud-lite:latest
make sanity-test-tarball TARBALL=./dist/google-cloud-cli-573.0.0-linux-x86_64-lite.tar.gz
```

---

## Test Verification Matrix

### 1. Docker Image Checks (`test_docker_image`)

| Check | Command Executed | Expected Outcome | Failure Meaning |
| :--- | :--- | :--- | :--- |
| **Default Entrypoint** | `gcloud --version` | Exits 0, prints version | Python runtime or PATH is broken |
| **System Info Integrity** | `gcloud info --format=json` | Exits 0, valid JSON output | Corrupted core SDK packages |
| **Beta Command Tree** | `gcloud beta --help` | Exits 0 (if installed) or skipped cleanly | Beta component installation corrupted |
| **Storage Command Tree** | `gcloud storage --help` | Exits 0 | `botocore` missing or surface metadata broken |
| **BigQuery Utility** | `bq version` | Exits 0 | `bq` companion CLI broken |
| **gsutil & crcmod** | `gsutil version -l` | Exits 0, output contains `compiled crcmod: True` | Missing `py3-crcmod` (slow Python fallback) |
| **Bloat Absence Invariant** | Shell assertion | Target paths do NOT exist in image | Regression: deleted bloat was reintroduced |

### 2. Tarball Checks (`test_tarball`)

| Check | Verification | Expected Outcome | Failure Meaning |
| :--- | :--- | :--- | :--- |
| **Archive Size Threshold** | File byte count | Size < 85 MB compressed | Unexpected bloat slipped into tarball |
| **Archive Table of Contents** | `tar -tzf` inspection | No prohibited paths (`bundledpythonunix`, `anthoscli`, `botocore/data/ec2`) | Archive packager missed stripping steps |
| **Extraction & Smoke Test** | `tar -xzf` to temp dir & execute `bin/gcloud --version` | Exits 0 | Broken archive, bad symlinks, or missing files |
