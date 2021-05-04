packer {
  required_version = ">= 1.7.0"
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
  env     = ["LC_ALL=C"]
  shebang = "/bin/sh -eux"
}

build {
  source "source.arm-image.raspios" {
    output_filename = "build/raspberry_pi.img"

    # This ensures that we don't run out of disk space in the provisioner steps.
    target_image_size = 4 * 1024 * 1024 * 1024
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
