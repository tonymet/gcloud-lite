# syntax=docker/dockerfile:1
ARG BASE_IMAGE=alpine:latest
ARG CLOUD_SDK_VERSION=573.0.0

# ------------------------------------------------------------------------------
# Stage 1: Builder & Stripper
# ------------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS builder

ARG CLOUD_SDK_VERSION
ARG GCLOUD_SDK_VERSION
ARG INSTALL_COMPONENTS=""
ARG TARGETARCH
ARG ARCH=x86_64

ENV CLOUD_SDK_VERSION=${GCLOUD_SDK_VERSION:-${CLOUD_SDK_VERSION}}
ENV PATH=/google-cloud-sdk/bin:$PATH
ENV CLOUDSDK_PYTHON=/usr/bin/python3
ENV PYTHONDONTWRITEBYTECODE=1

RUN apk add --no-cache curl python3 pigz tar bash ca-certificates

RUN case "${TARGETARCH:-}" in \
      amd64) SDK_ARCH="x86_64" ;; \
      arm64) SDK_ARCH="arm" ;; \
      *) SDK_ARCH="${ARCH:-x86_64}" ;; \
    esac && \
    echo "Fetching Google Cloud SDK ${CLOUD_SDK_VERSION} for ${SDK_ARCH}..." && \
    curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${SDK_ARCH}.tar.gz" | tar -xz -C / && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image && \
    if [ -n "${INSTALL_COMPONENTS}" ]; then \
        gcloud components install -q ${INSTALL_COMPONENTS}; \
    fi && \
    rm -rf /google-cloud-sdk/platform/bundledpythonunix && \
    rm -rf /google-cloud-sdk/bin/anthoscli && \
    find /google-cloud-sdk/lib/third_party/botocore/data -mindepth 1 -maxdepth 1 -type d ! -name "s3*" ! -name "_*" ! -name "endpoints*" -exec rm -rf {} + && \
    rm -rf /google-cloud-sdk/deb /google-cloud-sdk/rpm && \
    rm -rf /google-cloud-sdk/.install/.backup \
           /google-cloud-sdk/.install/download_cache \
           /google-cloud-sdk/.install/partial_downloads && \
    gcloud --version && \
    find /google-cloud-sdk -type d -name "__pycache__" -prune -exec rm -rf {} + && \
    find /google-cloud-sdk -type f -name "*.py[co]" -delete && \
    mkdir -p /dist && \
    tar -cf - -C / google-cloud-sdk | pigz > "/dist/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${SDK_ARCH}-lite.tar.gz" && \
    sha256sum "/dist/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${SDK_ARCH}-lite.tar.gz" > "/dist/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${SDK_ARCH}-lite.tar.gz.sha256"

# ------------------------------------------------------------------------------
# Stage 2: Tarball Export Target
# Extract to local folder via:
#   DOCKER_BUILDKIT=1 docker build --target export-tarball --output type=local,dest=./dist .
# ------------------------------------------------------------------------------
FROM scratch AS export-tarball
COPY --from=builder /dist/ /

# ------------------------------------------------------------------------------
# Stage 3: Minimal Runnable Image (Default Target)
# ------------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS runtime

ARG CLOUD_SDK_VERSION
ARG GCLOUD_SDK_VERSION
ENV CLOUD_SDK_VERSION=${GCLOUD_SDK_VERSION:-${CLOUD_SDK_VERSION}}
ENV PATH=/google-cloud-sdk/bin:$PATH
ENV CLOUDSDK_PYTHON=/usr/bin/python3
ENV PYTHONDONTWRITEBYTECODE=1
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1
ENV CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1
ENV CLOUDSDK_CORE_DISABLE_UPDATE_CHECK=1
ENV CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true

RUN apk add --no-cache python3 py-crcmod \
        py-openssl curl bash ca-certificates

COPY --from=builder /google-cloud-sdk /google-cloud-sdk

ENTRYPOINT [ "/google-cloud-sdk/bin/gcloud" ]
