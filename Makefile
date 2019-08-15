FILES       := $(wildcard boot/*)
LOOP_DEVICE := /dev/loop0
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
deploy:

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
$(OS_IMG): $(OS_ZIP) $(FILES)
	unzip -p $< > $@
	@mkdir $(MOUNTPOINT)
	losetup --partscan $(LOOP_DEVICE) $@
	mount $(LOOP_DEVICE)p1 $(MOUNTPOINT)
	cp $(filter-out $<,$^) $(MOUNTPOINT)/
	umount $(MOUNTPOINT)
	losetup --detach $(LOOP_DEVICE)
	@rmdir $(MOUNTPOINT)

$(OS_ZIP):
	wget --output-document $@ $(OS_URL)

/dev/%: $(OS_IMG)
	dd bs=4M if=$< of=$@ status=progress conv=fsync
