#!/bin/zsh
set -e
die () {
    echo "$1"
    exit 1
}
[[ -v PROJECT ]] || die "\$PROJECT is unset"
[[ -v OBJECT ]] ||  die "\$OBJECT is unset"
[[ -v BUCKET ]] ||  die "\$BUCKET is unset"
[[ -v KMS_KEYPATH ]] ||  die "\$KMS_KEYPATH is unset"
build_tarball(){
    [[ -v 1 ]] || die "\$1 is unset"
    [[ -v CLOUD_SDK_VERSION ]] || die "CLOUD_SDK_VERSION is unset"
    [[ -v ARCH ]] || die "ARCH is unset"
    echo "Building and exporting stripped tarball via Docker BuildKit..."
    mkdir -p "$1"
    DOCKER_BUILDKIT=1 docker build \
        --target export-tarball \
        --build-arg CLOUD_SDK_VERSION="${CLOUD_SDK_VERSION}" \
        --build-arg ARCH="${ARCH}" \
        --output type=local,dest="$1" \
        .
}

github_release(){
    [[ -v 1 ]] || die "\$1 is unset"
    [[ -v CLOUD_SDK_VERSION ]] || die "\$CLOUD_SDK_VERSION is unset"
    [[ -v GH_TOKEN ]] || die "\$GH_TOKEN is unset"
    [[ -v GH_OWNER ]] || die "\$GH_OWNER is unset"
    [[ -v GH_REPO ]] || die "\$GH_REPO is unset"
    TAG=$CLOUD_SDK_VERSION
    cd "$1"
    echo "creating release"
    du -sh *gz
    ../gcloud-cmd github-release -tag "$TAG" -owner "$GH_OWNER" -repo "$GH_REPO" -file "google-cloud-cli-${TAG}-linux-x86_64-lite.tar.gz" -commit "master" -k "$KMS_KEYPATH"
    [[ $? -eq 0 ]] || die "ERROR: create release fail"
    cd -
}

function record_version(){
    echo "gcs object gcloud-lite/version-saved version=$CLOUD_SDK_VERSION"
    ./gcloud-cmd set-object "$BUCKET" "$OBJECT" "$CLOUD_SDK_VERSION"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: set-object failed"
    fi
}

function trigger_build(){
    echo "pub-sub build version=$CLOUD_SDK_VERSION"
    TOPIC="gcloud-lite"
    ./gcloud-cmd pub-sub-build "$PROJECT" "$TOPIC" "$CLOUD_SDK_VERSION"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: pubsub failed"
    fi
}

function check_version(){
    set +e
    echo "check_version $CLOUD_SDK_VERSION"
    [[ -n ${CLOUD_SDK_VERSION} ]] || die "\$CLOUD_SDK_VERSION is unset"
    curl -s -f -X HEAD -o/dev/null \
        "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz"
    if [[ $? -ne 18 ]] ; then
        echo "ERROR: version $CLOUD_SDK_VERSION is not available"
        exit 0
    fi
    set -e
}
CLOUD_SDK_VERSION=$(./gcloud-cmd active-version "$BUCKET" "$OBJECT")
export CLOUD_SDK_VERSION
check_version
build_tarball "$1"
./test/sanity-test.sh tarball "$1/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}-lite.tar.gz"
github_release "$1"
record_version
trigger_build