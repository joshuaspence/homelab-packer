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

#===============================================================================
# Manual Targets
#===============================================================================

KPARTX    := sudo kpartx
MAKEFLAGS += --no-print-directory
MOUNT     := sudo mount
UMOUNT    := sudo umount --recursive

# TODO: Do we need to copy `qemu-arm-static`?
.PHONY: chroot
chroot:
	$(MAKE) mount
	$(MOUNT) --bind /dev $(TARGET)/dev
	$(MOUNT) --bind /dev/pts $(TARGET)/dev/pts
	$(MOUNT) --bind /proc $(TARGET)/proc
	$(MOUNT) --bind /sys $(TARGET)/sys

	sudo sed --in-place 's/^/#CHROOT /g' $(TARGET)/etc/ld.so.preload
	sudo cp /usr/bin/qemu-arm-static  $(TARGET)/usr/bin/
	sudo chroot $(TARGET)
	sudo sed --in-place 's/^#CHROOT //g' $(TARGET)/etc/ld.so.preload

	$(MAKE) unmount

# TODO: Ensure that `$(SOURCE)` and `$(TARGET)` are set.
# TODO: Pass `-o uid=$USER,gid=$USER` to `mount`.
.PHONY: mount
mount:
	# Create a device map.
	$(KPARTX) -a -s $(SOURCE)
	$(eval LOOP_DEVICE := $(addprefix /dev/mapper/,$(shell $(KPARTX) -l $(SOURCE) | cut --delimiter=' ' --fields=1)))

	# Mount partitions.
	mkdir $(TARGET)
	$(MOUNT) $(word 2,$(LOOP_DEVICE)) $(TARGET)
	$(MOUNT) $(word 1,$(LOOP_DEVICE)) $(TARGET)/boot

# TODO: Ensure that `$(SOURCE)` and `$(TARGET)` are set.
.PHONY: unmount
unmount:
	$(UMOUNT) $(TARGET)
	rmdir $(TARGET) 
	$(KPARTX) -d $(SOURCE)
