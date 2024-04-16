#!/bin/zsh
set -e

build_tarball(){
    if [[ -z $CLOUD_SDK_VERSION ]]; then
        echo "CLOUD_SDK_VERSION is unset"
        exit 1
    fi
    if [[ -z $ARCH ]]; then
        echo "ARCH is unset"
        exit 1
    fi
    # CLOUD_SDK_VERSION=471.0.0
    # ARCH=x86_64
    echo "starting download"
    mkdir -p $1 && cd $1 && \
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
        tar xzf google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
        rm google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
        rm -rf google-cloud-sdk/platform/bundledpythonunix && \
        rm -rf google-cloud-sdk/bin/anthoscli && \
        rm -rf google-cloud-sdk/lib/third_party/botocore && \
        tar -czf  google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}-lite.tar.gz google-cloud-sdk 
    cd ..
}

github_release(){
    if [[ -z $TAG ]]; then
        echo "TAG is unset"
        exit 1
    fi
    cd $1
    echo "creating release"
    res=$(\
        curl -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/tonymet/gcloud-lite/releases \
    -d "{\"tag_name\":\"$TAG\",\"target_commitish\":\"master\",\"name\":\"$TAG\",\"body\":\"gcloud lite release\",\"draft\":true,\"prerelease\":false,\"generate_release_notes\":false}"\
    )

    echo "uploading asset" 
    ID=$(echo $res | jq .id)
    curl -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/octet-stream" \
    "https://uploads.github.com/repos/tonymet/gcloud-lite/releases/$ID/assets?name=google-cloud-cli-$TAG-linux-x86_64-lite.tar.gz" \
    --data-binary "@google-cloud-cli-$TAG-linux-x86_64-lite.tar.gz"
}

build_tarball $1
github_release $1