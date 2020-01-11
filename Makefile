#===============================================================================
# Macros
#===============================================================================
DD              = sudo dd bs=4M conv=fsync status=progress
KPARTX          = sudo kpartx
MOUNT           = sudo mount
PACKER          = sudo packer
PACKER_OPTS    ?=
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
OUTPUT = build/raspberry_pi.img

#===============================================================================
# Targets
#===============================================================================
.PHONY: build
build: build/raspian.zip
	cat packer.yaml | yaml2json | $(PACKER) build $(PACKER_OPTS) -

# TODO: Maybe add the following flags to `systemd-nspawn`: `--ephemeral`, `--private-users`, `--bind`, `--bind-ro`, `--tmpfs`, `--register`
.PHONY: chroot
chroot:
	@$(MAKE) mount
	$(SYSTEMD_NSPAWN) --directory=$(CHROOT) --chdir=/
	@$(MAKE) unmount

.PHONY: clean
clean:
	rm --force --recursive build

.PHONY: clean-all
clean-all: clean
	rm --force --recursive packer_cache

.PHONY: deploy
deploy:
	! test -b $(DEVICE) && test -c $(DEVICE)
	$(DD) if=$(OUTPUT) of=$(DEVICE)

# TODO: Pass `-o uid=$USER,gid=$USER` to `mount`.
.PHONY: mount
mount:
	# Create a device map.
	$(KPARTX) -a -s $(OUTPUT)
	$(eval LOOP_DEVICE := $(addprefix /dev/mapper/,$(shell $(KPARTX) -l $(OUTPUT) | cut --delimiter=' ' --fields=1)))

	# Mount partitions.
	mkdir $(CHROOT)
	$(MOUNT) $(word 2,$(LOOP_DEVICE)) $(CHROOT)
	$(MOUNT) $(word 1,$(LOOP_DEVICE)) $(CHROOT)/boot

.PHONY: unmount
unmount:
	$(UMOUNT) $(CHROOT)
	rmdir $(CHROOT)
	$(KPARTX) -d $(OUTPUT)

#===============================================================================
# Rules
#===============================================================================
.DELETE_ON_ERROR:
build/raspian.zip:
	RASPIAN_URL=$$(curl --no-location --output /dev/null --show-error --silent --write-out '%{redirect_url}' https://downloads.raspberrypi.org/raspbian_lite_latest)
	curl --silent $$RASPIAN_URL.sha256 | awk '{print $$1}' > $@.sha256
	curl --output $@ --progress-bar $$RASPIAN_URL
