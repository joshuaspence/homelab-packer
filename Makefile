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

check_defined = $(strip $(foreach 1,$1,$(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = $(if $(value $1),,$(error Undefined $1$(if $2, ($2))$(if $(value @), required by target `$@')))

CHROOT_SOURCE := build/raspberry_pi.img
CHROOT_TARGET := mnt

# TODO: Maybe add the following flags to `systemd-nspawn`: `--ephemeral`, `--private-users`, `--bind`, `--bind-ro`, `--tmpfs`, `--register`
.PHONY: chroot
chroot:
	$(MAKE) mount SOURCE=$(CHROOT_SOURCE) TARGET=$(CHROOT_TARGET)
	sudo systemd-nspawn --directory=$(CHROOT_TARGET) --quiet $(CHROOT_OPTS)
	$(MAKE) unmount SOURCE=$(CHROOT_SOURCE) TARGET=$(CHROOT_TARGET)

# TODO: Pass `-o uid=$USER,gid=$USER` to `mount`.
.PHONY: mount
mount:
	$(call check_defined,SOURCE TARGET)

	# Create a device map.
	$(KPARTX) -a -s $(SOURCE)
	$(eval LOOP_DEVICE := $(addprefix /dev/mapper/,$(shell $(KPARTX) -l $(SOURCE) | cut --delimiter=' ' --fields=1)))

	# Mount partitions.
	mkdir $(TARGET)
	$(MOUNT) $(word 2,$(LOOP_DEVICE)) $(TARGET)
	$(MOUNT) $(word 1,$(LOOP_DEVICE)) $(TARGET)/boot

.PHONY: unmount
unmount:
	$(call check_defined,SOURCE TARGET)
	$(UMOUNT) $(TARGET)
	rmdir $(TARGET)
	$(KPARTX) -d $(SOURCE)

.DELETE_ON_ERROR:
.ONESHELL:
build/raspian.zip:
	RASPIAN_URL=$$(curl --no-location --output /dev/null --show-error --silent --write-out '%{redirect_url}' https://downloads.raspberrypi.org/raspbian_lite_latest)
	curl --silent $$RASPIAN_URL.sha256 | awk '{print $$1}' > $@.sha256
	curl --output $@ --progress-bar $$RASPIAN_URL
