FILES  := $(wildcard rootfs/*)
INPUT  ?= raspian.zip
OUTPUT ?=

raspian.img: raspian.zip $(FILES)
	unzip $< $@
        $(eval MOUNTPOINT := $(shell mktemp --directory))
	mount -o loop $@ $(MOUNTPATH)
	cp $(filter-out $<,$^) $(MOUNTPATH)/
	umount $(MOUNTPATH)
	rmdir $(MOUNTPATH)

.PHONY: build
build: raspian.img

.PHONY: deploy
deploy: raspian.img
	dd bs=4M if=$< of=$(OUTPUT) status=progress conv=fsync
