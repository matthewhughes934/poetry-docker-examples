DOCKERFILES = $(wildcard *.dockerfile)
IMAGES = $(DOCKERFILES:.dockerfile=)
DEV_IMAGES = $(DOCKERFILES:.dockerfile=-dev)

.PHONY: $(IMAGES)
$(IMAGES):
	docker build \
		--tag $@ \
		--file $@.dockerfile \
		--target production \
		$${BUILD_ARGS:-} .

.PHONY: $(DEV_IMAGES)
$(DEV_IMAGES):
	docker build \
		--tag $@ \
		--file $(subst -dev,,$@).dockerfile \
		--target development \
		$${BUILD_ARGS:-} .
