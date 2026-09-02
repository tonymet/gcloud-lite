# Weekly Release & Operations Guide

This guide describes how **gcloud-lite** automated releases operate and how to trigger or debug builds.

---

## 1. Automated Weekly Release Flow

The release process is intended to run weekly (e.g. via Cloud Scheduler triggering Cloud Build):

1. **Trigger**: Cloud Scheduler sends an HTTP POST to the Cloud Build trigger.
2. **Gatekeeper Check**:
   - `gcloud-cmd active-version ${_BUCKET} ${_OBJECT}` computes the expected next release version.
   - Cloud Build checks if that version exists on `https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/...`.
   - **If NOT published yet**: Gatekeeper creates `/workspace/skip_build` and exits 0; all remaining steps exit in 0.1s.
   - **If published**: Cloud Build proceeds to build both artifacts.
3. **Build & Export**: Multi-stage Dockerfile compiles and selectively prunes the SDK, producing the runtime container and exporting the `.tar.gz` to `/workspace/dist`.
4. **Sanity Verification**: Runs `./test/sanity-test.sh all` on both artifacts.
5. **Publishing**:
   - Pushes `gcloud-lite:latest` and `gcloud-lite:<VERSION>` to Artifact Registry.
   - Publishes the `.tar.gz` to GitHub Releases and signs it with Cloud KMS.
   - Updates the version in Google Cloud Storage (`gcloud-cmd set-object`).

---

## 2. Prerequisites & IAM Permissions

The Cloud Build Service Account (`<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com`) requires the following roles:

* **Secret Manager Secret Accessor** (`roles/secretmanager.secretAccessor`): Required to read `GH_TOKEN`.
* **Cloud KMS CryptoKey Signer/Verifier** (`roles/cloudkms.signerVerifier`): Required to sign release artifacts.
* **Storage Object Admin** (`roles/storage.objectAdmin`): Required to read and update the version tracker object in GCS.
* **Artifact Registry Writer** (`roles/artifactregistry.writer`): Required to push container images.

---

## 3. Manual Release Workflows

### Trigger Cloud Build Manually
```bash
gcloud builds submit --config cloudbuild.yaml .
```

### Build & Test Locally
```bash
# 1. Build the Docker image
docker build --build-arg GCLOUD_SDK_VERSION=573.0.0 -t gcloud-lite .

# 2. Export the stripped tarball
make export-tarball CLOUD_SDK_VERSION=573.0.0

# 3. Run sanity test
./test/sanity-test.sh all gcloud-lite ./dist/google-cloud-cli-573.0.0-linux-x86_64-lite.tar.gz
```
