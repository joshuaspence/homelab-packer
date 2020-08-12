source "arm-image" "main" {
  iso_checksum_url     = "https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-${var.raspbian_release_date}/${var.raspbian_release}-raspbian-buster-lite.zip.sha256"
  iso_checksum_type    = "sha256"
  iso_url              = "https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-${var.raspbian_release_date}/${var.raspbian_release}-raspbian-buster-lite.zip"
  iso_target_extension = "img"
  output_filename      = "build/raspberry_pi.img"
  target_image_size    = "4294967296"
}

locals {
  env = [
    "APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1",
    "LC_ALL=C",
  ]

  shebang = "/bin/sh -eux"
}

build {
  sources = ["source.arm-image.main"]

  # Set hostname on boot.
  provisioner "file" {
    source      = "files/hosts"
    destination = "/etc/hosts"
  }

  provisioner "file" {
    source      = "files/hostname.service"
    destination = "/lib/systemd/system/raspberrypi-hostname.service"
  }

  provisioner "shell" {
    inline         = ["systemctl enable raspberrypi-hostname.service"]
    inline_shebang = local.shebang
  }

  # Change timezone.
  provisioner "shell" {
    inline = [
      "test -f /usr/share/zoneinfo/${var.timezone}",
      "rm /etc/localtime",
      "echo ${var.timezone} > /etc/timezone",
      "dpkg-reconfigure --frontend noninteractive tzdata",
    ]

    inline_shebang   = local.shebang
    environment_vars = local.env
  }

  # Enable SSH.
  provisioner "shell" {
    inline = [
      "systemctl enable ssh.service",
      "systemctl disable sshswitch.service",
    ]

    inline_shebang   = local.shebang
    environment_vars = local.env
  }

  # Configure Wi-Fi.
  provisioner "shell" {
    inline = [
      "[ -n '${var.wifi_name}' -a -n '${var.wifi_password}' ] || exit 0",
      "echo 'country=${var.wifi_country}' >> /etc/wpa_supplicant/wpa_supplicant.conf",
      "wpa_passphrase '${var.wifi_name}' '${var.wifi_password}' | grep --extended-regexp --invert-match '^\\s+#psk=' >> /etc/wpa_supplicant/wpa_supplicant.conf",
    ]

    inline_shebang = local.shebang
  }

  provisioner "shell" {
    inline           = ["apt-get remove --quiet --yes --purge raspberrypi-net-mods"]
    inline_shebang   = local.shebang
    environment_vars = local.env
  }

  # Disable Debian changelogs.
  provisioner "shell" {
    inline         = ["rm /etc/apt/apt.conf.d/20listchanges"]
    inline_shebang = local.shebang
  }

  # Upgrade system packages.
  provisioner "shell" {
    inline = [
      "apt-get --quiet update",
      "apt-get --quiet --yes --with-new-pkgs upgrade",
      "apt-get --quiet --yes dist-upgrade",
    ]

    inline_shebang   = local.shebang
    environment_vars = local.env
  }

  # Install Docker.
  provisioner "shell" {
    inline = [
      "curl --fail --location --show-error --silent https://get.docker.com | sh",
      "usermod --append --groups docker pi",
    ]

    inline_shebang   = local.shebang
    environment_vars = local.env
  }

  # Install Kubernetes.
  provisioner "shell" {
    inline = [
      # Disable swap.
      # TODO: I'm not sure if this is working (according to the output from `swapon --summary`).
      "dphys-swapfile swapoff",
      "dphys-swapfile uninstall",
      "systemctl disable dphys-swapfile",

      # Enable cgroups.
      "sed --expression 's/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' --in-place /boot/cmdline.txt",

      # Install Kubernetes.
      "curl --fail --show-error --silent https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list",
      "apt-get --quiet update",
      "apt-get --no-install-recommends --quiet --yes install kubeadm kubectl kubelet",
    ]

    inline_shebang   = local.shebang
    environment_vars = local.env
  }

  # Cleanup.
  provisioner "shell" {
    inline = [
      "apt-get --quiet --yes --option Apt::AutoRemove::SuggestsImportant=false autoremove",
      "apt-get --quiet clean",
      "rm --force --recursive /var/lib/apt/lists/*",
    ]

    inline_shebang   = local.shebang
    environment_vars = local.env
  }

  provisioner "shell" {
    inline           = ["find /var/log -type f -print0 | xargs --null truncate --size=0"]
    inline_shebang   = local.shebang
  }

  provisioner "shell" {
    inline = [
      "rm --force /etc/passwd- /etc/group- /etc/shadow- /etc/gshadow- /etc/subuid- /etc/subgid-",
      "rm --force /etc/apt/sources.list~ /etc/apt/trusted.gpg~",
      "rm --force /var/cache/debconf/*-old /var/lib/dpkg/*-old",

      # TODO: Do we need this?
      "true > /etc/machine-id",
    ]

    inline_shebang = local.shebang
  }
}

variable "raspbian_release" {
  type    = string
  default = "2020-02-05"
}

variable "raspbian_release_date" {
  type    = string
  default = "2020-02-07"
}

variable "timezone" {
  type    = string
  default = "Australia/Sydney"
}

variable "wifi_country" {
  type    = string
  default = "AU"
}

variable "wifi_name" {
  type    = string
  default = ""
}

variable "wifi_password" {
  type      = string
  default   = ""
  sensitive = true
}
