#===============================================================================
# Macros
#===============================================================================
DD              = $(SUDO) dd bs=4M conv=fsync status=progress
KPARTX          = $(SUDO) kpartx
MKDIR           = mkdir
MOUNT           = $(SUDO) mount
PACKER          = packer
PACKER_OPTS    ?=
RM				= rm --force
RMDIR           = rmdir
SUDO            = sudo
SYNC            = $(SUDO) sync
SYSTEMD_NSPAWN  = $(SUDO) systemd-nspawn --quiet
UMOUNT          = $(SUDO) umount --recursive

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
	@$(MAKE) --always-make $(IMAGE)

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
	$(DD) if=$(IMAGE) of=$(DEVICE)
	$(SYNC) $(DEVICE)

.PHONY: fmt
fmt:
	$(PACKER) fmt .

.PHONY: mount
mount: $(CHROOT)

.PHONY: unmount
unmount:
	$(UMOUNT) $(CHROOT)
	$(RMDIR) $(CHROOT)
	$(KPARTX) -d $(IMAGE)

.PHONY: validate
validate:
	$(PACKER) validate .

#===============================================================================
# Rules
#===============================================================================

$(CHROOT): | $(IMAGE)
	@# Create a device map.
	$(KPARTX) -a -s $|
	$(eval LOOP_DEVICE := $(addprefix /dev/mapper/,$(shell $(KPARTX) -l $| | cut --delimiter=' ' --fields=1)))

	@# Mount partitions.
	$(MKDIR) $@
	$(MOUNT) $(word 2,$(LOOP_DEVICE)) $@
	$(MOUNT) $(word 1,$(LOOP_DEVICE)) $@/boot

$(IMAGE):
	$(SUDO) $(PACKER) build .
