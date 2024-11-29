.PHONY:test
IMAGE=gcloud-lite-build
gcloud-lite-build:
	docker build -f ci/Dockerfile  . -t  us-west1-docker.pkg.dev/tonym-us/tonym-us/${IMAGE}

cloudbuild-ci:
	 gcloud beta builds submit --config ci/cloudbuild.yaml .

push-gcloud-lite-build:
	docker push us-west1-docker.pkg.dev/tonym-us/tonym-us/${IMAGE}

docker-run:
	docker run -v${HOME}:/root --env-file=.env ${IMAGE} build

test:
	go test .
	shellcheck -s bash *sh
