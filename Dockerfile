FROM alpine 
RUN apk add --no-cache python3 py-crcmod \
        py-openssl curl
ARG CLOUD_SDK_VERSION=472.0.0
ENV CLOUD_SDK_VERSION=$CLOUD_SDK_VERSION
ENV PATH /google-cloud-sdk/bin:$PATH
ENV CLOUDSDK_PYTHON=/usr/bin/python3
# Download and install cloud sdk. Review the components I install, you may not need them.
RUN ARCH=x86_64 && \
    curl -s -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
    tar xzf google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
    rm google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
    rm -rf /google-cloud-sdk/platform/bundledpythonunix && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image && \
    # gcloud components remove -q bq && \
    gcloud components install -q beta && \
    # gcloud components install -q gke-gcloud-auth-plugin && \
    rm -rf $(find google-cloud-sdk/ -regex ".*/__pycache__") && \
    rm -rf google-cloud-sdk/.install/.backup && \
    rm -rf google-cloud-sdk/bin/anthoscli && \
    gcloud --version
ENV PATH /google-cloud-sdk/bin:$PATH
ENV CLOUDSDK_PYTHON=/usr/bin/python3

ENTRYPOINT [ "/google-cloud-sdk/bin/gcloud" ]
