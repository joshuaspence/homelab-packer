.PHONY: build
build:
	sudo packer build -var-file variables.json packer.json

.PHONY: clean
clean:
	rm --force --recursive build

.PHONY: clean-all
clean-all: clean
	rm --force --recursive packer_cache

.PHONY: deploy
deploy:
	sudo flasher --device /dev/sdb --image build/image --verify

# NOTE: `raspberrypi.local` with mDNS. You can use `avahi-browse` to browse
# hosts and services on the LAN. See
# https://www.raspberrypi.org/documentation/remote-access/ip-address.md.
.PHONY: ping
ping:
	ping raspberrypi.local

.PHONY: ssh
ssh:
	sshpass -p raspberry ssh pi@raspberrypi.local
