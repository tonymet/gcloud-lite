# gcloud-lite CLI Distribution

[Google's gcloud CLI distribution](https://cloud.google.com/sdk/docs/install)
is bloated with unnecessary dependencies including a complete python3
installation and large anthos binary.  This results in slower instance boot
times, and costly storage & transfer fees

GCloud-Lite is a distribution of the CLI that strips these unnessary dependencies to reduce the size by > 75% 

## Artifacts
* [Runnable docker image](https://console.cloud.google.com/artifacts/docker/tonym-us/us-west1/gcloud-lite/gcloud-lite?hl=en&project=tonym-us) — 93% smaller
* [tgz tarball](https://github.com/tonymet/gcloud-lite/releases) — 75% smaller

## Discussions About gcloud CLI bloat
* https://github.com/GoogleCloudPlatform/gsutil/issues/1732
