#===============================================================================
# Macros
#===============================================================================
DD      = $(SUDO) dd bs=4M conv=fsync status=progress
KPARTX  = $(SUDO) kpartx
MKDIR   = mkdir
MOUNT   = $(SUDO) mount
NSPAWN  = $(SUDO) systemd-nspawn --quiet
PACKER  = $(SUDO) --preserve-env packer
RM      = rm --force
RMDIR   = rmdir
SUDO    = sudo
SYNC    = $(SUDO) sync
UMOUNT  = $(SUDO) umount --recursive
YQ      = yq --prettyPrint

#===============================================================================
# Configuration
#===============================================================================
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables

.SHELLFLAGS += -o errexit
.SHELLFLAGS += -o nounset

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
	$(NSPAWN) --directory=$(CHROOT) --chdir=/
	@$(MAKE) unmount

.PHONY: clean
clean:
	$(RM) --recursive build

.PHONY: clean-all
clean-all: clean
	$(RM) --recursive packer_cache

.PHONY: deploy
deploy:
	@# Copy image.
	$(DD) if=$(IMAGE) of=$(DEVICE)

	@# Add `cloud-init` data.
	$(SYNC) $(DEVICE)
	$(eval BOOT_MOUNTPOINT := $(shell mktemp --directory))
	$(MOUNT) $(DEVICE)1 $(BOOT_MOUNTPOINT)
	$(SUDO) cp files/meta-data.yaml $(BOOT_MOUNTPOINT)/meta-data
	$(YQ) eval '.hostname = "$(HOSTNAME)"' files/user-data.yaml | $(SUDO) sponge $(BOOT_MOUNTPOINT)/user-data
	$(UMOUNT) $(BOOT_MOUNTPOINT)
	@$(RMDIR) $(BOOT_MOUNTPOINT)

	@# Synchronize cached writes.
	$(SYNC) $(DEVICE)

.PHONY: mount
mount: $(CHROOT)

.PHONY: unmount
unmount:
	$(UMOUNT) $(CHROOT)
	$(RMDIR) $(CHROOT)
	$(KPARTX) -d $(IMAGE)

#===============================================================================
# Rules
#===============================================================================

# TODO: Use `losetup` instead of `kpartx` (see solo-io/packer-plugin-arm-image#115).
$(CHROOT): | $(IMAGE)
	@# Create a device map.
	$(KPARTX) -a -s $|
	$(eval LOOP_DEVICE := $(addprefix /dev/mapper/,$(shell $(KPARTX) -l $| | cut --delimiter=' ' --fields=1)))

	@# Mount partitions.
	$(MKDIR) $@
	$(MOUNT) $(word 2,$(LOOP_DEVICE)) $@
	$(MOUNT) $(word 1,$(LOOP_DEVICE)) $@/boot

$(IMAGE):
	$(eval RASPIOS_URL := $(shell curl --fail --head --no-location --output /dev/null --show-error --silent --write-out '%{redirect_url}' https://downloads.raspberrypi.org/raspios_lite_armhf_latest))
	$(PACKER) build -var raspios_url=$(RASPIOS_URL) .
