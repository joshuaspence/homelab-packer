#===============================================================================
# Macros
#===============================================================================
DD              = sudo dd bs=4M conv=fsync status=progress
KPARTX          = sudo kpartx
MOUNT           = sudo mount
PACKER          = sudo packer
PACKER_OPTS    ?=
RM				= rm --force
SYSTEMD_NSPAWN  = sudo systemd-nspawn --quiet
UMOUNT          = sudo umount --recursive

# Load user variables from `config.json` if such a file exists.
PACKER_OPTS += $(if $(wildcard config.json),-var-file config.json)

#===============================================================================
# Configuration
#===============================================================================
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables

#===============================================================================
# Target Definitions
#===============================================================================
CHROOT = mnt
IMAGE  = build/raspberry_pi.img

#===============================================================================
# Targets
#===============================================================================
.PHONY: build
build: build/raspian.zip
	cat packer.yaml | yaml2json | $(PACKER) build $(PACKER_OPTS) -

# TODO: Maybe add the following flags to `systemd-nspawn`: `--ephemeral`, `--private-users`, `--bind`, `--bind-ro`, `--tmpfs`, `--register`.
.PHONY: chroot
chroot:
	@$(MAKE) mount
	$(SYSTEMD_NSPAWN) --directory=$(CHROOT) --chdir=/
	@$(MAKE) unmount

.PHONY: clean
clean:
	$(RM) --recursive build

.PHONY: clean-all
clean-all: clean
	$(RM) --recursive packer_cache

.PHONY: deploy
deploy:
	test -c $(DEVICE)
	$(DD) if=$(IMAGE) of=$(DEVICE)

.PHONY: mount
mount:
	# Create a device map.
	$(KPARTX) -a -s $(IMAGE)
	$(eval LOOP_DEVICE := $(addprefix /dev/mapper/,$(shell $(KPARTX) -l $(IMAGE) | cut --delimiter=' ' --fields=1)))

	# Mount partitions.
	mkdir $(CHROOT)
	$(MOUNT) $(word 2,$(LOOP_DEVICE)) $(CHROOT)
	$(MOUNT) $(word 1,$(LOOP_DEVICE)) $(CHROOT)/boot

.PHONY: unmount
unmount:
	$(UMOUNT) $(CHROOT)
	rmdir $(CHROOT)
	$(KPARTX) -d $(IMAGE)

#===============================================================================
# Rules
#===============================================================================

# TODO: This shouldn't be needed, see https://github.com/hashicorp/packer/issues/8586.
.DELETE_ON_ERROR:
build/raspian.zip:
	$(eval RASPIAN_URL := $(shell curl --no-location --output /dev/null --show-error --silent --write-out '%{redirect_url}' https://downloads.raspberrypi.org/raspbian_lite_latest))
	curl --output $@ --progress-bar $(RASPIAN_URL)
	curl --silent $(RASPIAN_URL).sha256 | awk '{print $$1}' > $@.sha256
