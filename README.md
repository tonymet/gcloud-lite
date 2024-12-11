# gcloud-lite CLI Distribution

[Google's gcloud CLI distribution](https://cloud.google.com/sdk/docs/install)
is bloated with unnecessary dependencies including a complete python3
installation and large anthos binary.  This results in slower instance boot
times, and costly storage & transfer fees

GCloud-Lite is a distribution of the CLI that strips these unnessary dependencies to reduce the size by > 75% 

## Artifacts
* [Runnable docker image](https://console.cloud.google.com/artifacts/docker/tonym-us/us-west1/gcloud-lite/gcloud-lite?hl=en&project=tonym-us) — 93% smaller
* [tgz tarball](https://github.com/tonymet/gcloud-lite/releases) — 75% smaller

## Running the Docker Image
```
$ docker pull us-west1-docker.pkg.dev/tonym-us/gcloud-lite/gcloud-lite
# re-use existing credentials with -v
$ docker run -v$HOME:/root us-west1-docker.pkg.dev/tonym-us/gcloud-lite/gcloud-lite  compute instances list
```
### Running ghutil, bq and other utilities
```
$ docker run -v$HOME:/root --entrypoint ghutil  us-west1-docker.pkg.dev/tonym-us/gcloud-lite/gcloud-lite ARGS
$ docker run -v$HOME:/root --entrypoint bq us-west1-docker.pkg.dev/tonym-us/gcloud-lite/gcloud-lite   ARGS
```

## Downloading gcloud-lite .tgz release
```
$ curl -LO https://github.com/tonymet/gcloud-lite/releases/download/472.0.0/google-cloud-cli-472.0.0-linux-x86_64-lite.tar.gz
$ tar -zxf *gz
```

## Verifying .tgz Release Signature
`public-key.pub` is found in this repo
`ARCHIVE` & `ARCHIVE.sig` are included in each release
*Verified OK* is expected for a good signature.
```
PUBLIC_KEY=public-key.pub
ARCHIVE=google-cloud-cli-487.0.0-linux-x86_64-lite.tar.gz
openssl dgst -verify "${PUBLIC_KEY}" \
    -signature "${ARCHIVE}.sig" 
    "${ARCHIVE}"
Verified OK
```



## Benchmarks
Tested on GCP Compute Instance e2-medium
| Image        | Time      | Improvement |
|--------------|-----------|------------|
| google-cloud-cli | 1m29s     | -     |
| gcloud-lite      | 12.6s  |    86%  |

```
# time  docker pull us-west1-docker.pkg.dev/tonym-us/gcloud-lite/gcloud-lite
Using default tag: latest
latest: Pulling from tonym-us/gcloud-lite/gcloud-lite
Status: Downloaded newer image for us-west1-docker.pkg.dev/tonym-us/gcloud-lite/gcloud-lite:latest
us-west1-docker.pkg.dev/tonym-us/gcloud-lite/gcloud-lite:latest

real    0m12.620s
user    0m0.474s
sys     0m0.114s
```

```
# time docker pull gcr.io/google.com/cloudsdktool/google-cloud-cli:latest
latest: Pulling from google.com/cloudsdktool/google-cloud-cli

Status: Downloaded newer image for gcr.io/google.com/cloudsdktool/google-cloud-cli:latest
gcr.io/google.com/cloudsdktool/google-cloud-cli:latest

real    1m28.957s
user    0m1.130s
sys     0m0.189s
```
## Issues Filed to Address SDK Bloat
* https://github.com/GoogleCloudPlatform/gsutil/issues/1732
* https://issuetracker.google.com/issues/324114897?pli=1
* https://issuetracker.google.com/issues/239207289

## Acknowledgements
* Big thanks to [@framegrace](https://github.com/framegrace) for [developing the logic to strip unnecessary components](https://github.com/GoogleCloudPlatform/gsutil/issues/1732#issuecomment-2029591598)
