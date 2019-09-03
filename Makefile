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

KPARTX := sudo kpartx
MOUNT  := sudo mount
UMOUNT := sudo umount

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

	$(UMOUNT) $(TARGET)/dev/pts
	$(UMOUNT) $(TARGET)/dev
	$(UMOUNT) $(TARGET)/proc
	$(UMOUNT) $(TARGET)/sys
	$(MAKE) unmount

# TODO: Ensure that `$(SOURCE)` and `$(TARGET)` are set.
# TODO: Pass `-o uid=$USER,gid=$USER` to `mount`.
# TODO: Use `make` functions instead of `cut`, `sed`, `sort` and `uniq`.
.PHONY: mount
mount:
	# Create a device map.
	$(KPARTX) -a -s $(SOURCE)
	$(eval LOOP_DEVICE := $(shell $(KPARTX) -l $(SOURCE) | cut --delimiter=' ' --fields=5 | sort | uniq | sed 's|^/dev/|/dev/mapper/|'))

	# Mount partitions.
	mkdir $(TARGET)
	$(MOUNT) $(LOOP_DEVICE)p2 $(TARGET)
	$(MOUNT) $(LOOP_DEVICE)p1 $(TARGET)/boot

# TODO: Ensure that `$(SOURCE)` and `$(TARGET)` are set.
# TODO: Can we use `umount --recursive`?
.PHONY: unmount
unmount:
	$(UMOUNT) $(TARGET)/boot
	$(UMOUNT) $(TARGET)
	rmdir $(TARGET) 
	$(KPARTX) -d $(SOURCE)
