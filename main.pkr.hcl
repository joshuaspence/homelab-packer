packer {
  required_version = ">= 1.7.0"

  required_plugins {
    arm-image = {
      source  = "github.com/solo-io/arm-image"
      version = ">= 0.2.5"
    }
  }
}

# TODO: Automatically look up the latest version from
# https://downloads.raspberrypi.org/raspios_lite_armhf_latest.
variable "raspios_url" {
  type    = string
  default = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip"
}

source "arm-image" "raspios" {
  iso_checksum         = "file:${var.raspios_url}.sha256"
  iso_url              = var.raspios_url
  iso_target_extension = "img"
}

locals {
  env = [
    "DEBIAN_FRONTEND=noninteractive",
    "LC_ALL=C",
  ]

  shebang = "/bin/sh -eux"
}

build {
  source "source.arm-image.raspios" {
    output_filename = "build/raspberry_pi.img"

    # This ensures that we don't run out of disk space in the provisioner steps.
    target_image_size = 4 * 1024 * 1024 * 1024
  }

  # Install additional locales.
  provisioner "shell" {
    inline = [
      "echo 'locales locales/locales_to_be_generated multiselect en_AU.UTF-8 UTF-8, en_US.UTF-8 UTF-8' | debconf-set-selections",
      "rm /etc/locale.gen",
      "dpkg-reconfigure locales",
    ]

    environment_vars = local.env
    inline_shebang   = local.shebang
  }

  # Enable SSH.
  provisioner "shell" {
    inline = [
      "systemctl enable ssh.service",
      "systemctl disable sshswitch.service",
    ]

    environment_vars = local.env
    inline_shebang   = local.shebang
  }

  # Update package index.
  provisioner "shell" {
    inline           = ["apt-get --quiet update"]
    environment_vars = local.env
    inline_shebang   = local.shebang
  }

  # Install Docker.
  provisioner "shell" {
    script           = "scripts/install_docker.sh"
    environment_vars = local.env
  }

  # Install and configure `cloud-init`.
  provisioner "shell" {
    inline = [
      "apt-get --quiet --yes install cloud-init",
      "sed --expression 's|$| ds=nocloud;seedfrom=/boot/|' --in-place /boot/cmdline.txt",
    ]

    environment_vars = local.env
    inline_shebang   = local.shebang
  }

  provisioner "file" {
    source      = "files/cloud-init.yaml"
    destination = "/etc/cloud/cloud.cfg"
  }

  # Upgrade system packages.
  provisioner "shell" {
    inline           = ["apt-get --quiet --yes upgrade"]
    environment_vars = local.env
    inline_shebang   = local.shebang
  }

  # Remove unnecessary packages.
  provisioner "shell" {
    inline = [
      "apt-get --quiet --yes purge libraspberrypi-doc raspberrypi-net-mods",
      "dpkg --get-selections *-dev | cut --fields=1 | xargs apt-get --quiet --yes purge",
    ]

    environment_vars = local.env
    inline_shebang   = local.shebang
  }

  # Cleanup.
  provisioner "shell" {
    inline = [
      "apt-get --quiet clean",
      "rm --recursive --force /var/lib/apt/*",
      "rm --force /var/cache/debconf/*-old",
      "rm --force /var/lib/dpkg/*-old",

      "rm --force /etc/passwd- /etc/group-",
      "rm --force /etc/shadow- /etc/gshadow-",
      "rm --force /etc/subuid- /etc/subgid-",

      "true > /etc/machine-id",
      "rm --force /var/lib/dbus/machine-id",
      "rm --force /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub",

      "find /var/log -type f -print0 | xargs --null truncate --size=0",
    ]
    environment_vars = local.env
    inline_shebang   = local.shebang
  }

  # Shrink the image by reclaiming unused disk space.
  post-processor "shell-local" {
    command = "tools/pishrink/pishrink.sh -s build/raspberry_pi.img"
  }

  post-processor "compress" {
    output              = "build/raspberry_pi.img.gz"
    keep_input_artifact = true
  }
}
