#!/bin/zsh
set -e

build_tarball(){
    if [[ -z $1 ]]; then
        echo "\$1 is unset"
        exit 1
    fi
    if [[ -z $CLOUD_SDK_VERSION ]]; then
        echo "CLOUD_SDK_VERSION is unset"
        exit 1
    fi
    if [[ -z $ARCH ]]; then
        echo "ARCH is unset"
        exit 1
    fi
    echo "starting download"
    mkdir -p $1 && cd $1 && \
    curl -s -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
        tar xzf google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
        rm google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
        rm -rf google-cloud-sdk/platform/bundledpythonunix && \
        rm -rf google-cloud-sdk/bin/anthoscli && \
        rm -rf google-cloud-sdk/lib/third_party/botocore && \
        tar -czf  google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}-lite.tar.gz google-cloud-sdk && \ 
        cd ..
}

github_release(){
    if [[ -z $1 ]]; then
        echo "\$1 is unset"
        exit 1
    fi
    if [[ -z $CLOUD_SDK_VERSION ]]; then
        echo "CLOUD_SDK_VERSION is unset"
        exit 1
    fi
    if [[ -z $GH_TOKEN ]]; then
        echo "GH_TOKEN is unset"
        exit 1
    fi
    TAG=$CLOUD_SDK_VERSION
    cd $1
    echo "creating release"
    res=$(\
        curl -s -L -f \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/tonymet/gcloud-lite/releases \
    -d "{\"tag_name\":\"$TAG\",\"target_commitish\":\"master\",\"name\":\"$TAG\",\"body\":\"gcloud lite release\",\"draft\":false,\"prerelease\":false,\"generate_release_notes\":false}"\
    )
    if [[ $? -ne 0 ]]; then
        echo "ERROR: create release fail"
        echo "res=$res"
        exit 1
    fi
    ID=$(echo $res | jq .id)
    echo "uploading asset id=$ID" 
    curl -s -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/octet-stream" \
    "https://uploads.github.com/repos/tonymet/gcloud-lite/releases/$ID/assets?name=google-cloud-cli-$TAG-linux-x86_64-lite.tar.gz" \
    --data-binary "@google-cloud-cli-$TAG-linux-x86_64-lite.tar.gz"
    cd ..
}

function record_version(){
    echo "gcs object gcloud-lite/version-saved version=$CLOUD_SDK_VERSION"
    ./gcloud-cmd set-object tonym.us gcloud-lite/version-saved $CLOUD_SDK_VERSION
    if [[ $? -ne 0 ]]; then
        echo "ERROR: set-object failed"
    fi
}

function trigger_build(){
    echo "pub-sub build version=$CLOUD_SDK_VERSION"
    ./gcloud-cmd pub-sub-build $CLOUD_SDK_VERSION
    if [[ $? -ne 0 ]]; then
        echo "ERROR: pubsub failed"
    fi
}

function check_version(){
    set +e
    if [[ -z $CLOUD_SDK_VERSION ]]; then
        echo "\$CLOUD_SDK_VERSION is unset"
        exit 1
    fi
    curl -s -f -X HEAD -o/dev/null \
        "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-$CLOUD_SDK_VERSION-linux-x86_64.tar.gz"
    if [[ $? -ne 18 ]] ; then
        echo "ERROR: version $CLOUD_SDK_VERSION is not available"
        exit 0
    fi
    set -e
}

check_version
build_tarball $1
github_release $1
record_version
trigger_build