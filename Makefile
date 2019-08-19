.PHONY: build
build:
	sudo packer build -var-file variables.json packer.json

.PHONY: clean
clean:
	rm --force --recursive build

.PHONY: clean-all
clean-all: clean
	rm --force --recursive packer_cache

# TODO: Move this to a `post-processor` in `packer.json`.
.PHONY: deploy
deploy:
	sudo flasher --device /dev/sdb --image build/image --verify
