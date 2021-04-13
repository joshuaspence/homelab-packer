#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

readonly BASE_URL='https://download.docker.com/linux/raspbian'
readonly KEYRING='/usr/share/keyrings/docker-archive-keyring.gpg'
readonly SOURCE_LIST='sources.list.d/docker.list'

curl --fail --location --show-error --silent "${BASE_URL}/gpg" | gpg --dearmor --output "${KEYRING}"
echo "deb [arch=$(dpkg --print-architecture) signed-by=${KEYRING}] ${BASE_URL} $(lsb_release --codename --short) stable" > "/etc/apt/${SOURCE_LIST}"
apt-get --quiet --no-list-cleanup --option "Dir::Etc::sourcelist=${SOURCE_LIST}" --option Dir::Etc::sourceparts=- update
apt-get --quiet --yes install docker-ce docker-ce-cli

# TODO: Move this to `cloud-init`.
usermod --append --groups docker pi
