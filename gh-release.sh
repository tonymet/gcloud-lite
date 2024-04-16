# curl -L \
#   -X POST \
#   -H "Accept: application/vnd.github+json" \
#   -H "Authorization: Bearer $GH_TOKEN" \
#   -H "X-GitHub-Api-Version: 2022-11-28" \
#   https://api.github.com/repos/tonymet/gcloud-lite/releases \
#   -d '{"tag_name":"471.0.0","target_commitish":"master","name":"471.0.0","body":"gcloud lite release","draft":true,"prerelease":false,"generate_release_notes":false}'

ID=151444996
  curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/octet-stream" \
  "https://uploads.github.com/repos/tonymet/gcloud-lite/releases/$ID/assets?name=google-cloud-cli-471.0.0-linux-x86_64-lite.tar.gz" \
  --data-binary "@google-cloud-cli-471.0.0-linux-x86_64-lite.tar.gz"