# gcloud-lite Architecture & Pipeline Design

This document details the architecture, design rationale, and operational lifecycle of **gcloud-lite**, an optimized, stripped distribution of the Google Cloud SDK CLI.

---

## 1. Overview & Goals

Google Cloud's official `google-cloud-cli` distribution is over **2.8 GB** uncompressed, containing complete embedded Python runtimes, large binaries (such as Anthos), hundreds of unused AWS service schemas, and unnecessary documentation and caches.

**gcloud-lite** achieves an **85%+ size reduction** (~350 MB container image, ~80 MB compressed tarball) while maintaining 100% backward compatibility with core tools: `gcloud`, `gsutil`, `bq`, and storage interoperability.

---

## 2. End-to-End Pipeline Architecture

The entire weekly release process is consolidated into a single root [cloudbuild.yaml](file:///home/tonymet/sotion/gcloud-lite/cloudbuild.yaml):

```mermaid
flowchart TD
    TRIGGER["Weekly Scheduler / Trigger"] --> CB["cloudbuild.yaml"]
    
    subgraph Gatekeeper ["Step 1 & 2: Gatekeeper & Early Abort"]
        CB --> COMPILE["Compile gcloud-cmd (golang:alpine)"]
        COMPILE --> QUERY["Read target version from GCS (_BUCKET/_OBJECT)"]
        QUERY --> CHECK{"Published on dl.google.com?"}
        CHECK -->|"No (not yet)"| SKIP["touch /workspace/skip_build\n(Remaining steps exit in 0.1s, clean SUCCESS)"]
    end

    subgraph BuildEngine ["Step 3: Unified Multi-Stage Build"]
        CHECK -->|"Yes (200 OK)"| DOCKER["docker build (Multi-Stage Dockerfile)"]
        DOCKER -->|"Default Target"| IMG["Docker Image: gcloud-lite"]
        DOCKER -->|"--target export-tarball"| TAR["Stripped tar.gz + sha256 (/workspace/dist)"]
    end

    subgraph Verification ["Step 4: Sanity Test Guard"]
        IMG & TAR --> SANITY["test/sanity-test.sh all"]
    end

    subgraph Publishing ["Step 5 & 6: Release & Record"]
        SANITY --> GH["gcloud-cmd github-release (KMS Signed)"]
        GH --> GCS["gcloud-cmd set-object (Save version to GCS)"]
        GCS --> PUSH["Push Docker image to Artifact Registry"]
    end
```

---

## 3. Multi-Stage Dockerfile Architecture

The [Dockerfile](file:///home/tonymet/sotion/gcloud-lite/Dockerfile) uses a 3-stage pattern to build both the container image and exportable tarball from a single source of truth:

```mermaid
flowchart LR
    subgraph Stage1 ["Stage 1: builder"]
        B1["Download SDK tarball"] --> B2["Configure Telemetry/Updates"]
        B2 --> B3["Selective Pruning"]
        B3 --> B4["Compress /dist/*-lite.tar.gz + sha256"]
    end

    subgraph Stage2 ["Stage 2: export-tarball (scratch)"]
        B4 --> E1["COPY --from=builder /dist/ /"]
        E1 -.->|"docker build --target export-tarball --output ./dist"| E2["Host File: .tar.gz"]
    end

    subgraph Stage3 ["Stage 3: runtime (alpine:latest)"]
        R1["apk add python3, py-crcmod, curl, bash, ca-certs"]
        B3 -->|"COPY --from=builder /google-cloud-sdk"| R2["/google-cloud-sdk"]
        R1 --> R2
        R2 --> R3["ENTRYPOINT ['/google-cloud-sdk/bin/gcloud']"]
        R3 -.->|"docker build -t gcloud-lite ."| R4["Docker Image"]
    end
```

### Key Stages:
1. **`builder`**:
   - Stream unpacks upstream archive (`curl ... | tar -xz`).
   - Configures non-interactive defaults (`core/disable_usage_reporting`, `disable_update_check`).
   - Applies selective stripping (see Section 4).
   - Generates the compressed standalone `.tar.gz` and `.sha256` in `/dist/`.
2. **`export-tarball` (`FROM scratch`)**:
   - Copies `/dist/` to root. Used by BuildKit's local export to extract the release tarball to host in seconds without running a container.
3. **`runtime` (Default Final Stage)**:
   - Minimal Alpine base with system Python 3, fast C-compiled `py3-crcmod`, `ca-certificates`, and `bash`.
   - Copies the already-stripped `/google-cloud-sdk` directly from `builder`.
   - Leaves zero intermediate build tools (`pigz`, caches) in the runtime layers.

---

## 4. Stripping Invariants & Rationale

| Target Path | Action | Rationale | Size Saved |
| :--- | :--- | :--- | :--- |
| `platform/bundledpythonunix` | Removed | Container runtime provides clean system Python 3 | ~120 MB |
| `bin/anthoscli` | Removed | Heavy binary not required for core CLI operations | ~70 MB |
| `lib/third_party/botocore/data/` | **Selectively Pruned** | Only `s3*` models are retained; 350+ unused AWS models (EC2, SageMaker, IoT, etc.) are deleted. Enables `gcloud storage rsync` while eliminating bloat. | ~75 MB |
| `deb/`, `rpm/` | Removed | Upstream Linux package manager metadata not needed in containers | ~10 MB |
| `.install/.backup`, `.install/*cache` | Removed | Residual component manager cache from build phase | ~25 MB |
| `__pycache__`, `*.pyc`, `*.pyo` | Deleted | Python bytecode stripped; `PYTHONDONTWRITEBYTECODE=1` prevents runtime regeneration | ~30 MB |

---

## 5. Runtime Configuration & Telemetry Suppression

To prevent container hangs and suppress background network calls in headless/CI environments, the following environment variables are set by default in the image:

* `CLOUDSDK_CORE_DISABLE_PROMPTS=1`: Disables all interactive confirmation banners (e.g. attempting to install missing optional components fails immediately rather than hanging on stdin).
* `CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1`: Completely disables background update polling.
* `CLOUDSDK_CORE_DISABLE_UPDATE_CHECK=1`: Redundant safeguard against core update prompts.
* `CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true`: Disables Google telemetry reporting.
* `PYTHONDONTWRITEBYTECODE=1`: Prevents Python from writing `.pyc` files into the container's writable layer.
