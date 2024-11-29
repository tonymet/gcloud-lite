gcloud-lite-build:
	docker build -f ci/Dockerfile  . -t  us-west1-docker.pkg.dev/tonym-us/tonym-us/gcloud-lite-build

cloudbuild-ci:
	 gcloud beta builds submit --config ci/cloudbuild.yaml .

push-gcloud-lite-build:
	docker push us-west1-docker.pkg.dev/tonym-us/tonym-us/gcloud-lite-build
