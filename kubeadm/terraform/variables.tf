# SSH keys management
variable "ssh_key_path" {
  description = "SSH public key path"
  type        = string
  default     = "~/.ssh/terraform_rsa.pub"
}
variable "ssh_key_name" {
  description = "SSH public key name"
  type        = string
  default     = "terraform_key"
}
variable "ssh_key_id" {
  description = "Existing SSH key id from Hetzner Cloud (specify this, if you don't want to create new SSH key pair)"
  type        = string
  default     = ""
}

# Private network management
variable "network_name" {
  description = "Netork name in console"
  type        = string
  default     = "terraform-net"
}
variable "network_cidr" {
  description = "Network CIDR. Default value is a valid CIDR, but not acceptable by Hetzner Cloud and must be overriden"
  type        = string
  default     = "0.0.0.0/0"
}
variable "network_subnets" {
  description = "Subnets CIDRs. Default value is a valid CIDRs, but not acceptable by Hetzner Cloud and must be overriden"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
variable "network_type" {
  description = "Default network type"
  type        = string
  default     = "cloud"
}
variable "network_zone" {
  description = "Network zone"
  type        = string
  default     = "eu-central"
}
variable "network_id" {
  description = "Existing Network id from Hetzner Cloud (specify this, if you don't want to create new Network)"
  type        = string
  default     = ""
}

# Servers management
variable server_count {
  description = "Count of the servers to create"
  type        = number
  default     = 1
}
variable server_image {
  description = "Server image to use. Name or ID. Specify ID if you want to use your snapshot"
  type        = string
  default     = "ubuntu-18.04"
}
variable server_name_prefix {
  description = "Server prefix to use. If the final name is test-01, then specify test as a value"
  type        = string
  default     = "terraform"
}
variable server_type {
  description = "Server type"
  type        = string
  default     = "cpx21"
}
