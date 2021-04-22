#===============================================================================
# Macros
#===============================================================================
CLOUD_LOCALDS = cloud-localds
DD            = $(SUDO) dd bs=4M conv=fsync status=progress
KPARTX        = $(SUDO) kpartx
MKDIR         = mkdir
MOUNT         = $(SUDO) mount
NSPAWN        = $(SUDO) systemd-nspawn --quiet
PACKER        = packer
RM            = rm --force
RMDIR         = rmdir
SFDISK        = $(SUDO) sfdisk --quiet
SUDO          = sudo --preserve-env
SYNC          = $(SUDO) sync
UMOUNT        = $(SUDO) umount --recursive
YQ            = yq --prettyPrint

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
	$(DD) if=$(IMAGE) of=$(DEVICE)
	echo 'start=2048, size=1024, type=83' | $(SFDISK) --append $(DEVICE)
	$(YQ) eval '.hostname = "$(HOSTNAME)"' files/user-data.yaml | $(CLOUD_LOCALDS) - - files/meta-data.yaml | $(DD) of=$(DEVICE)3
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

$(CHROOT): | $(IMAGE)
	@# Create a device map.
	$(KPARTX) -a -s $|
	$(eval LOOP_DEVICE := $(addprefix /dev/mapper/,$(shell $(KPARTX) -l $| | cut --delimiter=' ' --fields=1)))

	@# Mount partitions.
	$(MKDIR) $@
	$(MOUNT) $(word 2,$(LOOP_DEVICE)) $@
	$(MOUNT) $(word 1,$(LOOP_DEVICE)) $@/boot

.ONESHELL: $(IMAGE)
$(IMAGE):
	RASPIOS_URL=$$(curl --fail --head --no-location --output /dev/null --show-error --silent --write-out '%{redirect_url}' https://downloads.raspberrypi.org/raspios_lite_armhf_latest)
	$(SUDO) $(PACKER) build -var raspios_url=$${RASPIOS_URL} .
