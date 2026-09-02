#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✓ [PASS]${NC} $1"; }
fail() { echo -e "${RED}✗ [FAIL]${NC} $1"; exit 1; }

test_docker_image() {
    local image="$1"
    echo "=================================================="
    echo "Running Sanity Tests on Docker Image: ${image}"
    echo "=================================================="

    # 1. Base command & version check
    echo -n "Checking 'gcloud --version' ... "
    docker run --rm "${image}" --version > /dev/null 2>&1 \
        && pass "gcloud runs with default entrypoint" \
        || fail "gcloud default entrypoint failed"

    # 2. SDK internal integrity via gcloud info
    echo -n "Checking 'gcloud info' JSON output ... "
    docker run --rm "${image}" info --format=json > /dev/null 2>&1 \
        && pass "gcloud info returned valid system info" \
        || fail "gcloud info threw an error"

    # 3. Beta component verification (if installed)
    echo -n "Checking 'gcloud beta' command tree ... "
    if docker run --rm "${image}" components list --format="value(state.name)" --filter="id=beta" 2>/dev/null | grep -q "Installed"; then
        docker run --rm "${image}" beta --help > /dev/null 2>&1 \
            && pass "beta component is functioning" \
            || fail "beta component is installed but broken"
    else
        pass "beta component is not installed (omitted as expected)"
    fi

    # 4. Storage command verification
    echo -n "Checking 'gcloud storage' command tree ... "
    docker run --rm "${image}" storage --help > /dev/null 2>&1 \
        && pass "storage surface is intact" \
        || fail "storage surface broken"

    # 5. bq entrypoint check
    echo -n "Checking 'bq version' entrypoint ... "
    docker run --rm --entrypoint bq "${image}" version > /dev/null 2>&1 \
        && pass "bq utility functions correctly" \
        || fail "bq utility failed"

    # 6. gsutil & compiled crcmod verification
    echo -n "Checking 'gsutil' and compiled crcmod ... "
    gsutil_info=$(docker run --rm --entrypoint gsutil "${image}" version -l 2>&1)
    if echo "${gsutil_info}" | grep -q "compiled crcmod: True"; then
        pass "gsutil runs and uses fast compiled C crcmod"
    else
        fail "gsutil compiled crcmod is missing (using slow Python fallback)"
    fi

    # 7. Verify bloat is stripped from image
    echo -n "Verifying stripped bloat inside container ... "
    docker run --rm --entrypoint /bin/sh "${image}" -c '
        set -e
        test ! -d /google-cloud-sdk/platform/bundledpythonunix || exit 1
        test ! -f /google-cloud-sdk/bin/anthoscli || exit 2
        # Verify botocore S3 model is retained but non-S3 models (e.g. ec2) are stripped
        test -d /google-cloud-sdk/lib/third_party/botocore/data/s3 || exit 3
        test ! -d /google-cloud-sdk/lib/third_party/botocore/data/ec2 || exit 4
        test ! -d /google-cloud-sdk/.install/.backup || exit 5
        # Verify no __pycache__ was left behind
        [ $(find /google-cloud-sdk -type d -name "__pycache__" | wc -l) -eq 0 ] || exit 6
    ' && pass "All targeted bloat is successfully absent" \
      || fail "Bloat detection check failed: unnecessary artifacts found inside image"

    echo ">> Docker Image Sanity Tests Passed Successfully!"
}

test_tarball() {
    local tarball="$1"
    echo "=================================================="
    echo "Running Sanity Tests on Tarball: ${tarball}"
    echo "=================================================="

    [ -f "${tarball}" ] || fail "Tarball file not found: ${tarball}"

    # 1. Archive size check (compressed archive should be < 85MB)
    local size_bytes
    size_bytes=$(wc -c < "${tarball}" | tr -d ' ')
    local max_allowed=$((85 * 1024 * 1024))
    if [ "${size_bytes}" -gt "${max_allowed}" ]; then
        fail "Tarball size (${size_bytes} bytes) exceeds 85MB threshold!"
    fi
    pass "Tarball size check passed ($((size_bytes / 1024 / 1024)) MB)"

    # 2. Archive structure check
    echo -n "Verifying archive table of contents ... "
    local toc
    toc=$(tar -tzf "${tarball}")

    # Ensure stripped paths are NOT in TOC
    if echo "${toc}" | grep -E "bundledpythonunix|bin/anthoscli|botocore/data/ec2|\.install/\.backup" > /dev/null; then
        fail "Tarball contains prohibited bloat artifacts"
    fi
    if ! echo "${toc}" | grep "botocore/data/s3" > /dev/null; then
        fail "Tarball is missing required botocore s3 model"
    fi
    pass "Archive TOC contains no stripped bloat"

    # 3. Extraction & Execution Smoke Test
    echo -n "Extracting to temp directory for smoke testing ... "
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "${tmp_dir:-}"' EXIT

    tar -xzf "${tarball}" -C "${tmp_dir}"
    [ -x "${tmp_dir}/google-cloud-sdk/bin/gcloud" ] || fail "gcloud executable missing after extraction"

    # Execute with local python3 if present
    if command -v python3 > /dev/null; then
        CLOUDSDK_PYTHON=$(command -v python3) "${tmp_dir}/google-cloud-sdk/bin/gcloud" --version > /dev/null 2>&1 \
            && pass "Extracted gcloud runs cleanly" \
            || fail "Extracted gcloud failed to execute with system python3"
    fi

    rm -rf "${tmp_dir}"
    trap - EXIT

    echo ">> Tarball Sanity Tests Passed Successfully!"
}

usage() {
    echo "Usage: $0 docker <IMAGE_TAG>"
    echo "       $0 tarball <PATH_TO_TAR_GZ>"
    echo "       $0 all <IMAGE_TAG> <PATH_TO_TAR_GZ>"
    exit 1
}

case "${1:-}" in
    docker)
        [ $# -eq 2 ] || usage
        test_docker_image "$2"
        ;;
    tarball)
        [ $# -eq 2 ] || usage
        test_tarball "$2"
        ;;
    all)
        [ $# -eq 3 ] || usage
        test_docker_image "$2"
        test_tarball "$3"
        ;;
    *)
        usage
        ;;
esac
