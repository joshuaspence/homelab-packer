.PHONY: build
build:
	sudo packer build -var-file config.json $(PACKER_OPTS) packer.json

.PHONY: clean
clean:
	rm --force --recursive build

.PHONY: clean-all
clean-all: clean
	rm --force --recursive packer_cache

# TODO: Move this to a `post-processor` in `packer.json`.
.PHONY: deploy
deploy:
	# TODO: Optionally add `--verify`
	$(call check_defined,DEVICE)
	sudo flasher --device $(DEVICE) --image build/image

qemu/arm-linux-user/qemu-arm-static:
	sudo apt-get --quiet --yes build-dep qemu
	wget -qO- https://download.qemu.org/qemu-4.1.0.tar.xz | tar xJf -
	mv qemu-4.1.0 qemu
	cd qemu && ./configure --static --disable-system --enable-linux-user
	cd qemu && make -j8
	mv qemu/arm-linux-user/qemu-arm qemu/arm-linux-user/qemu-arm-static

export PATH := qemu/arm-linux-user:$(PATH)

#===============================================================================
# Manual Targets
#===============================================================================

KPARTX    := sudo kpartx
MAKEFLAGS += --no-print-directory
MOUNT     := sudo mount
UMOUNT    := sudo umount --recursive

check_defined = $(strip $(foreach 1,$1,$(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = $(if $(value $1),,$(error Undefined $1$(if $2, ($2))$(if $(value @), required by target `$@')))

# NOTE: These steps were based on https://gist.github.com/htruong/7df502fb60268eeee5bca21ef3e436eb.
# TODO: Do we need to copy `qemu-arm-static`?
.PHONY: chroot
chroot:
	$(call check_defined,SOURCE TARGET)

	$(MAKE) mount
	$(MOUNT) --bind /dev $(TARGET)/dev
	$(MOUNT) --bind /dev/pts $(TARGET)/dev/pts
	$(MOUNT) --bind /proc $(TARGET)/proc
	$(MOUNT) --bind /sys $(TARGET)/sys

	sudo cp $$(which qemu-arm-static) $(TARGET)/usr/bin/qemu-arm-static
	sudo chown root:root $(TARGET)/usr/bin/qemu-arm-static

	sudo chroot $(TARGET)

	$(MAKE) unmount

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
