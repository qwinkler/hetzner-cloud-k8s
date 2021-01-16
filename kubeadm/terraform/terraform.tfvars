# specify existing ssh key id to use it:
# $ hcloud ssh-key list
# ssh_key_id = "9999999"

# or create a new ssh key:
ssh_key_name = "kube_ssh"
# ssh_key_path = "~/.ssh/id_rsa.pub"

# specify existing network id to use it:
# $ hcloud network list
# network_id = "999999"

# or create a new network:
network_name = "kube-net"
network_cidr = "10.10.0.0/24"
network_subnets = ["10.10.0.0/28"]

server_count = 1
server_image = "ubuntu-18.04"
server_name_prefix = "tf-kube"
server_type = "cpx21"