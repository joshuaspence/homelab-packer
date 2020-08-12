#===============================================================================
# Macros
#===============================================================================
CHROOT_OPTS    ?=
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
build:
	$(PACKER) build $(PACKER_OPTS) main.pkr.hcl

.PHONY: chroot
chroot:
	@$(MAKE) mount
	$(SYSTEMD_NSPAWN) --directory=$(CHROOT) --chdir=/ $(CHROOT_OPTS)
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
