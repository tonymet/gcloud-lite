#!/bin/zsh
set -e
die () {
    echo "$1"
    exit 1
}
[[ -v PROJECT ]] || die "\$PROJECT is unset"
[[ -v OBJECT ]] ||  die "\$OBJECT is unset"
[[ -v BUCKET ]] ||  die "\$BUCKET is unset"
build_tarball(){
    [[ -v 1 ]] || die "\$1 is unset"
    [[ -v CLOUD_SDK_VERSION ]] || die "CLOUD_SDK_VERSION is unset"
    [[ -v ARCH ]] || die echo "ARCH is unset"
    echo "starting download"
    mkdir -p "$1" && cd "$1" && \
    curl -s -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz" && \
        tar xzf "google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz" && \
        rm "google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz" && \
        rm -rf google-cloud-sdk/platform/bundledpythonunix && \
        rm -rf google-cloud-sdk/bin/anthoscli && \
        rm -rf google-cloud-sdk/lib/third_party/botocore && \
        tar -czf  "google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}-lite.tar.gz" google-cloud-sdk && \
        cd -
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
    ../gcloud-cmd github-release -tag "$TAG" -owner "$GH_OWNER" -repo "$GH_REPO" -file "google-cloud-cli-${TAG}-linux-x86_64-lite.tar.gz" -commit "master"
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
    ./gcloud-cmd pub-sub-build "$PROJECT" "$CLOUD_SDK_VERSION"
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
github_release "$1"
record_version
trigger_build