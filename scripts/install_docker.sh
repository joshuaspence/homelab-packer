#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

readonly BASE_URL='https://download.docker.com/linux/raspbian'
readonly KEYRING='/usr/share/keyrings/docker-archive-keyring.gpg'
readonly SOURCE_LIST='sources.list.d/docker.list'

curl --fail --location --show-error --silent "${BASE_URL}/gpg" | gpg --dearmor --output "${KEYRING}"
echo "deb [arch=$(dpkg --print-architecture || true) signed-by=${KEYRING}] ${BASE_URL} $(lsb_release --codename --short || true) stable" > "/etc/apt/${SOURCE_LIST}"
apt-get --quiet --no-list-cleanup --option "Dir::Etc::sourcelist=${SOURCE_LIST}" --option Dir::Etc::sourceparts=- update
apt-get --quiet --yes install docker-ce docker-ce-cli

# TODO: Move this to `cloud-init`.
usermod --append --groups docker pi

# TODO: Make this command idempotent.
sed --expression 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' --in-place /boot/cmdline.txt
