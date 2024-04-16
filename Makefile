gcloud-lite-build:
	docker build -f ci/Dockerfile  . -t  us-west1-docker.pkg.dev/tonym-us/tonym-us/gcloud-lite-build

push-gcloud-lite-build:
	docker push us-west1-docker.pkg.dev/tonym-us/tonym-us/gcloud-lite-build
