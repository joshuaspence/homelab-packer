FILES       := $(wildcard boot/*)
LOOP_DEVICE := $(shell sudo losetup --find)
MOUNTPOINT  := mnt
OS_IMG      := raspian.img
OS_URL      := https://downloads.raspberrypi.org/raspbian_lite_latest
OS_ZIP      := raspian.zip

#===============================================================================
# Configuration
#===============================================================================
.DELETE_ON_ERROR:

#===============================================================================
# Targets
#===============================================================================

.PHONY: build
build: $(OS_IMG)

.PHONY: clean
clean:
	rm --force $(OS_IMG)

.PHONY: clean-all
clean-all: clean
	rm --force $(OS_ZIP)

.PHONY: download
download: $(OS_ZIP)

.PHONY: deploy
deploy: $(OS_IMG)
	sudo dd bs=4M if=$< of=/dev/sdb status=progress conv=fsync

# NOTE: `raspberrypi.local` with mDNS. You can use `avahi-browse` to browse
# hosts and services on the LAN. See
# https://www.raspberrypi.org/documentation/remote-access/ip-address.md.
.PHONY: ping
ping:
	ping raspberrypi.local

.PHONY: ssh
ssh:
	sshpass -p raspberry ssh pi@raspberrypi.local

#===============================================================================
# Rules
#===============================================================================

# TODO: Check this.
# TODO: `$(MOUNTPOINT)` shouls be deleted on error.
$(OS_IMG): $(OS_ZIP) $(FILES)
	unzip -p $< > $@
	@mkdir $(MOUNTPOINT)
	sudo losetup --partscan $(LOOP_DEVICE) $@
	sudo mount -o uid=$$USER,gid=$$USER $(LOOP_DEVICE)p1 $(MOUNTPOINT)
	cp $(filter-out $<,$^) $(MOUNTPOINT)/
	sync $(MOUNTPOINT)
	sudo umount $(MOUNTPOINT)
	sudo losetup --detach $(LOOP_DEVICE)
	@rmdir $(MOUNTPOINT)

$(OS_ZIP):
	wget --output-document $@ $(OS_URL)

/dev/%: $(OS_IMG)
	dd bs=4M if=$< of=$@ status=progress conv=fsync
