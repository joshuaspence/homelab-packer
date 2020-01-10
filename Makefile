.PHONY: build
build: build/raspian.zip
	cat packer.yaml | yaml2json | sudo packer build -var-file config.json $(PACKER_OPTS) -

.PHONY: clean
clean:
	rm --force --recursive build

.PHONY: clean-all
clean-all: clean
	rm --force --recursive packer_cache

# TODO: Move this to a `post-processor` in `packer.json`.
.PHONY: deploy
deploy:
	$(call check_defined,DEVICE)
	sudo dd if=build/raspberry_pi.img of=$(DEVICE) bs=4M conv=fsync status=progress

#===============================================================================
# Manual Targets
#===============================================================================

KPARTX    := sudo kpartx
MAKEFLAGS += --no-print-directory
MOUNT     := sudo mount
UMOUNT    := sudo umount --recursive

CHROOT_SOURCE := build/raspberry_pi.img
CHROOT_TARGET := mnt

# TODO: Maybe add the following flags to `systemd-nspawn`: `--ephemeral`, `--private-users`, `--bind`, `--bind-ro`, `--tmpfs`, `--register`
.PHONY: chroot
chroot:
	$(MAKE) mount
	sudo systemd-nspawn --directory=$(CHROOT_TARGET) --quiet $(CHROOT_OPTS)
	$(MAKE) unmount

# TODO: Pass `-o uid=$USER,gid=$USER` to `mount`.
.PHONY: mount
mount:
	# Create a device map.
	$(KPARTX) -a -s $(CHROOT_SOURCE)
	$(eval LOOP_DEVICE := $(addprefix /dev/mapper/,$(shell $(KPARTX) -l $(CHROOT_SOURCE) | cut --delimiter=' ' --fields=1)))

	# Mount partitions.
	mkdir $(CHROOT_TARGET)
	$(MOUNT) $(word 2,$(LOOP_DEVICE)) $(CHROOT_TARGET)
	$(MOUNT) $(word 1,$(LOOP_DEVICE)) $(CHROOT_TARGET)/boot

.PHONY: unmount
unmount:
	$(UMOUNT) $(CHROOT_TARGET)
	rmdir $(CHROOT_TARGET)
	$(KPARTX) -d $(CHROOT_SOURCE)

.DELETE_ON_ERROR:
.ONESHELL:
build/raspian.zip:
	RASPIAN_URL=$$(curl --no-location --output /dev/null --show-error --silent --write-out '%{redirect_url}' https://downloads.raspberrypi.org/raspbian_lite_latest)
	curl --silent $$RASPIAN_URL.sha256 | awk '{print $$1}' > $@.sha256
	curl --output $@ --progress-bar $$RASPIAN_URL
