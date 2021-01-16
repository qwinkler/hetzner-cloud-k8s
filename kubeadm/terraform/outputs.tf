output "out_ssh_key_name" {
  description = "The name of the SSH key"
  value       = compact(concat(data.hcloud_ssh_key.selected.*.name, hcloud_ssh_key.new.*.name))
}

# output "out_network_id" {
#   description = "The ID of the Network"
#   value       = coalesce(join("", data.hcloud_network.selected.*.id), join("", hcloud_network.new.*.id))
# }

output "out_network_cidr" {
  description = "The CIDR of the Network"
  value       = coalesce(join("", data.hcloud_network.selected.*.ip_range), join("", hcloud_network.new.*.ip_range))
}

output "out_network_name" {
  description = "The name of the Network"
  value       = coalesce(join("", data.hcloud_network.selected.*.name), join("", hcloud_network.new.*.name))
}

output "out_server_masters_public_ips" {
  description = "Public IPs of the master servers"
  value       = zipmap(hcloud_server.masters.*.id, hcloud_server.masters.*.ipv4_address)
}

output "out_server_masters_private_ips" {
  description = "Private IPs of the master servers"
  value       = zipmap(hcloud_server_network.masters_net.*.server_id, hcloud_server_network.masters_net.*.ip)
}