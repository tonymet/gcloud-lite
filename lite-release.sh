CLOUD_SDK_VERSION=471.0.0
ARCH=x86_64
cd build && \
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
    tar xzf google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
    rm google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
    rm -rf google-cloud-sdk/platform/bundledpythonunix && \
    rm -rf google-cloud-sdk/bin/anthoscli && \
    rm -rf google-cloud-sdk/lib/third_party/botocore && \
    tar -czf  google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}-lite.tar.gz google-cloud-sdk && \
    rm -rf google-cloud-sdk