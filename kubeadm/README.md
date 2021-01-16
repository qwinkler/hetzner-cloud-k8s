# Kubernetes deployment on a single node with addons

During this tutorial you will configure single node Kubernetes cluster provisioned via kubeadm.  
Tools:
- Packer: to pre build needed image
- Terraform with S3 backend: to provision infrastructure
- Ansible: to configure servers in Packer and Terraform

## Pre tasks

### Hetzner Cloud

We need to create the hcloud token file:
```bash
# save your token into the variable
vi ~/.hcloud_token
export HCLOUD_TOKEN=$(cat ~/.hcloud_token)
```

Also, we will need the hetzner cloud dns api token:
```bash
vi ~/.hcloud_dns_token
export HCLOUD_DNS_TOKEN=$(cat ~/.hcloud_dns_token)
```

### [Wasabi](https://console.wasabisys.com/) - AWS S3 compatible storage platform

Create **tf-kube-state** bucket in eu-central-1 region.  
Create the next **TerraformStateAccess** policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::tf-kube-state"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::tf-kube-state/quickstart/terraform.tfstate"
    }
  ]
}
```

Create new user **terraform** with programmatic access only. Attach the **TerraformStateAccess** policy to this user.

Fill new user credentials into the `~/.aws/config` and `~/.aws/credentials` files with profile `wasabi_tf` and verify that everything works:  
```bash
aws --endpoint http://s3.eu-central-1.wasabisys.com/ --profile wasabi_tf s3 ls s3://tf-kube-state
```

Save **terraform** user keys into the environment variables:

```bash
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep -A 2 wasabi_tf | grep aws_access_key_id | awk -F "=" '{print $2}' | xargs)
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep -A 2 wasabi_tf | grep aws_secret_access_key | awk -F "=" '{print $2}' | xargs)

# optional. verify
env | grep AWS
```

Setup some env variables for later usage:
```bash
export VERSION_DOCKER=19.03.8
export VERSION_KUBERNETES=v1.17.8
export VERSION_CALICOCTL=v3.14.0
```

We are ready to go.

## Getting started

Create base image:
```bash
cd packer
# bash build.sh help - for more details
bash build.sh -d ${VERSION_DOCKER} -k ${VERSION_KUBERNETES} -c ${VERSION_CALICOCTL}
```

You will get an output:
```
--> hcloud: A snapshot was created: 'kube-node-...' (ID: 99999999)
```
Save the snapshot ID, we will need it later.  

Setup infrastructure via terraform:  
```bash
cd terraform
# set server_image as the snapshot ID that packer gave you
vi config/quickstart.tfvars
terraform init -backend-config=config/quickstart_backend.tfvars
terraform plan -var-file config/quickstart.tfvars
terraform apply -var-file config/quickstart.tfvars
```

Export the server IP/DNS:
```bash
# create SERVER_PRIVATE_IP with private ips
terraform output -json out_server_masters_private_ips | jq -r 'to_entries[].value'

# create HCLOUD_NET_NAME with network name
terraform output -json out_network_name

# optioanl. verify that everything is ok
env | grep "SERVER\|HCLOUD"
```

Add private key to be able to ssh on the created instance:  
```bash
ssh-add -k ~/.ssh/private/kube_ssh_rsa
```

Update init file and/or group vars and run the playbook. The example below:
```bash
cd ..
unset ANSIBLE_CONFIG
# change the hosts file
vi hosts.ini
ansible-playbook -v init.yaml \
  -e hetzner_private_network_ip="${SERVER_PRIVATE_IP}" \
  -e hetzner_cloud_token="${HCLOUD_TOKEN}" \
  -e hetzner_cloud_network="${HCLOUD_NET_NAME}" \
  -e kubernetes_version="${VERSION_KUBERNETES}" \
  -e hetzner_cloud_dns_token="${HCLOUD_DNS_TOKEN}"
```

Verify installation:
```console
$ ssh -l root master_ip
# kubectl get nodes
# kubectl get pod -A
```

# Adding more worker nodes

Update `server_count` variable in [terraform/config/quickstart.tfvars](terraform/config/quickstart.tfvars) file and re-run terraform.  

Update hosts and run playbook:  
```bash
vi hosts.ini
ansible-playbook add_worker.yaml
```

# Cleanup

We exposed ingress via LoadBalancer, therefore we need to remove it first:
```console
$ ssh -l root master_ip
# kubectl delete ns ingress
# exit
```

Then remove all of the servers:
```bash
cd terraform
terraform destroy -auto-approve
```

Manually remove Packer's snapshot from Hetzner Cloud console.  

Login to [Wasabi](https://console.wasabisys.com/) and delete the next things:  
- **tf-kube-state** bucket
- **terraform** user
- **TerraformStateAccess** policy

Also, cleanup credentials from `~/.aws/config` and `~/.aws/credentials` files

Remove `.terraform` directory.