packer {
  required_version = ">= 1.7.0"
}

variable "operating_system" {
  type = object({
    architecture   = string
    date           = string
    version        = string
    debian_release = string
  })

  # TODO: Automatically look up the latest version from
  # https://downloads.raspberrypi.org/raspios_lite_armhf_latest.
  default = {
    architecture   = "armhf"
    date           = "2021-03-25"
    version        = "2021-03-04"
    debian_release = "buster"
  }
}

locals {
  raspios_url = format(
    "https://downloads.raspberrypi.org/raspios_lite_%s/images/raspios_lite_%s-%s/%s-raspios-%s-%s-lite.zip",
    var.operating_system.architecture,
    var.operating_system.architecture,
    var.operating_system.date,
    var.operating_system.version,
    var.operating_system.debian_release,
    var.operating_system.architecture,
  )
}

variable "qemu_binary" {
  type    = string
  default = null
}

source "arm-image" "raspios" {
  iso_checksum         = "file:${local.raspios_url}.sha256"
  iso_url              = local.raspios_url
  iso_target_extension = "img"
  qemu_binary          = var.qemu_binary
}

locals {
  env = [
    "LC_ALL=C",
  ]

  shebang = "/bin/sh -eux"
}

build {
  source "source.arm-image.raspios" {
    output_filename = "build/raspberry_pi.img"
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

  # Install and configure `cloud-init`.
  provisioner "shell" {
    inline           = ["apt-get --quiet --yes install cloud-init"]
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
}
