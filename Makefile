.PHONY: test sanity-test-docker sanity-test-tarball export-tarball cloudbuild

cloudbuild:
	gcloud builds submit --config cloudbuild.yaml .

export-tarball:
	DOCKER_BUILDKIT=1 docker build --target export-tarball --build-arg CLOUD_SDK_VERSION=$${CLOUD_SDK_VERSION:-573.0.0} --output type=local,dest=$${DIST_DIR:-./dist} .

test:
	go test .
	shellcheck -s bash *sh test/*sh

sanity-test-docker:
	chmod +x test/sanity-test.sh
	./test/sanity-test.sh docker $${IMAGE_TAG:-gcloud-lite:latest}

sanity-test-tarball:
	chmod +x test/sanity-test.sh
	./test/sanity-test.sh tarball $${TARBALL}
