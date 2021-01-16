# HCLOUD_TOKEN environment variable must be set
provider "hcloud" {}

terraform {
  required_version = "~> 0.12"
  backend "s3" {}
}

# hack: create new resources or use existing ones
locals {
  create_ssh_key = "${var.ssh_key_id == "" ? 1 : 0}"
  create_network = "${var.network_id == "" ? 1 : 0}"
  ds_count = length(data.hcloud_datacenters.all.names)
}

# list of available datacenters
data "hcloud_datacenters" "all" {} 

# ssh keys management
data "hcloud_ssh_key" "selected" {
  count = "${1 - local.create_ssh_key}"
  name = var.ssh_key_name
}
resource "hcloud_ssh_key" "new" {
  count = local.create_ssh_key
  name = var.ssh_key_name
  public_key = file("${var.ssh_key_path}")
}

# private network management
data "hcloud_network" "selected" {
  count = "${1 - local.create_network}"
  id = "${var.network_id}"
}
resource "hcloud_network" "new" {
  count = local.create_network
  name = var.network_name
  ip_range = var.network_cidr
}
resource "hcloud_network_subnet" "new_subnet" {
  count = local.create_network * length(var.network_subnets)
  network_id = tonumber(coalesce(join("", hcloud_network.new.*.id)))
  type = var.network_type
  network_zone = var.network_zone
  ip_range = var.network_subnets[count.index]
}

# servers management
resource "hcloud_server" "masters" {
  count = var.server_count
  image = var.server_image
  name = format("${var.server_name_prefix}-%02s", count.index + 1)
  server_type = var.server_type
  datacenter = data.hcloud_datacenters.all.names[count.index%local.ds_count]
  ssh_keys = compact(concat(data.hcloud_ssh_key.selected.*.name, hcloud_ssh_key.new.*.name))
}
resource "hcloud_server_network" "masters_net" {
  count = var.server_count
  server_id = hcloud_server.masters[count.index].id
  network_id = tonumber(coalesce(join("", data.hcloud_network.selected.*.id), join("", hcloud_network.new.*.id)))
}