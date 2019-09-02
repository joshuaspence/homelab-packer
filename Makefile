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

# TODO: Pass `-o uid=$USER,gid=$USER` to `mount`.
.PHONY: chroot
chroot:
	$(eval LOOP_DEVICE := $(shell losetup --find))
	sudo losetup --partscan $(LOOP_DEVICE) $(SOURCE)
	mkdir $(TARGET)
	sudo mount $(LOOP_DEVICE)p2 $(TARGET)
	sudo mount $(LOOP_DEVICE)p1 $(TARGET)/boot

	sudo mount --bind /dev $(TARGET)/dev
	sudo mount --bind /dev/pts $(TARGET)/dev/pts
	sudo mount --bind /proc $(TARGET)/proc
	sudo mount --bind /sys $(TARGET)/sys

	sudo sed --in-place 's/^/#CHROOT /g' $(TARGET)/etc/ld.so.preload

	sudo cp /usr/bin/qemu-arm-static  $(TARGET)/usr/bin/

	sudo chroot $(TARGET) /bin/bash

	sudo sed --in-place 's/^#CHROOT //g' $(TARGET)/etc/ld.so.preload
	sudo umount $(TARGET)/dev/pts
	sudo umount $(TARGET)/dev
	sudo umount $(TARGET)/proc
	sudo umount $(TARGET)/sys
	sudo umount $(TARGET)/boot
	sudo umount $(TARGET)

# TODO: Should we use `kpartx` instead of `losetup`?
# TODO: Ensure that `$(SOURCE)` and `$(TARGET)` are set.
.PHONY: mount
mount:
	$(eval LOOP_DEVICE := $(shell losetup --find))
	sudo losetup --partscan $(LOOP_DEVICE) $(SOURCE)
	mkdir $(TARGET)
	sudo mount $(LOOP_DEVICE)p2 $(TARGET)
	sudo mount $(LOOP_DEVICE)p1 $(TARGET)/boot

# TODO: We should use `losetup --detach` rather than `losetup --detach-all`.
.PHONY: unmount
unmount:
	sudo umount $(TARGET)/boot
	sudo umount $(TARGET)
	rmdir $(TARGET) 
	sudo losetup --detach-all

