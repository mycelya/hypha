# Here we boot in rescue mode which doesn't write
# anything to the disk of the server, that's why 
# execution of flatcar script writes a whole OS
# on an empty disk.

# Define the Packer configuration and required plugins
packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1.4.0"
    }
  }
}

# Define input variables for the configuration
variable "channel" {
  type    = string
  default = "beta" # Default Flatcar release channel e.g., beta, stable, alpha
}

variable "hcloud_token" {
  type      = string
  default   = env("HCLOUD_TOKEN")
  sensitive = true # Mark as sensitive to prevent logging of the token
}

source "hcloud" "flatcar" {
  token = var.hcloud_token # Use the Hetzner Cloud API token from variable

  image    = "ubuntu-24.04"
  location = "fsn1"
  rescue   = "linux64" # Enable rescue mode with 64-bit Linux for SSH access

  snapshot_labels = {
    os      = "flatcar"   # Label indicating the OS is Flatcar
    channel = var.channel # Label for the Flatcar release channel
  }

  ssh_username = "root" # SSH user for provisioning (root in rescue mode)
}

# Define the build process
build {
  # First source block for x86 architecture
  source "hcloud.flatcar" {
    name          = "x86"
    server_type   = "cx22"
    snapshot_name = "flatcar-${var.channel}-x86"
  }

  # Second source block for ARM architecture
  source "hcloud.flatcar" {
    name          = "arm"
    server_type   = "cax11"
    snapshot_name = "flatcar-${var.channel}-arm"
  }

  # Provisioner to execute shell commands on the instance
  provisioner "shell" {
    inline = [
      # Download script and dependencies
      # Install gawk GNU Awk non-interactively
      "apt-get -y install gawk",
      # Download the Flatcar installation script
      "curl -fsSLO --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 --connect-timeout 20 https://raw.githubusercontent.com/flatcar/init/flatcar-master/bin/flatcar-install",
      # Make the script executable
      "chmod +x flatcar-install",

      # Run the Flatcar installation script
      "./flatcar-install -s -o hetzner -C ${var.channel}",
    ]
  }
}
