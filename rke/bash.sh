#!/usr/bin/env bash

# Usage:
# wget -q https://url/to/raw/create.sh
# chmod +x create.sh
# htoken=replaceme privateip=192.168 email="email@gmail.com" create.sh

# define sensitive variables
_private_ip_beginning="${privateip}" # if full ip is "192.168.1.1", then fill it with "192.168"
HETZNER_TOKEN="${htoken}"
CERT_MANAGER_ISSUER_EMAIL="${email}"
echo "${HETZNER_TOKEN}" > ~/.htoken

# define static variables
PRIVATE_IP=$(
  ifconfig | 
  sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' |
  grep ${_private_ip_beginning}
)
KUBERNETES_VERSION="v1.16.9"
_kubernetes_version_rke="rancher1-1"
HELM3_VERSION="v3.1.1"

DOCKER_VERSION="19.03.8"
RKE_VERSION="v1.0.8"

set -x pipefail

# install useful tools
apt-get update && apt-get install -y git tree vim

# install Docker
curl -s https://get.docker.com | VERSION=${DOCKER_VERSION} sh

# install RKE
wget -qO /usr/local/bin/rke https://github.com/rancher/rke/releases/download/${RKE_VERSION}/rke_linux-amd64
chmod +x /usr/local/bin/rke

# create RKE configuration
mkdir -p rke && cd rke

# generate ssh key to be able to ssh to yourself
cat /dev/zero | ssh-keygen -q -N ""
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

cat <<EOF > test_config.yaml
# list of rke versions: https://github.com/rancher/kontainer-driver-metadata/blob/8bbeabc1a62870be38bd674df8cc30a88215d1b9/rke/k8s_rke_system_images.go
kubernetes_version: "${KUBERNETES_VERSION}-${_kubernetes_version_rke}"
cluster_name: test
nodes:
- internal_address: ${PRIVATE_IP}
  user: root
  role:
    - controlplane
    - etcd
    - worker
monitoring:
  provider: metrics-server
network:
  plugin: calico
dns:
  provider: coredns
cloud_provider:
  name: external
ingress:
  provider: none
EOF
rke up --config test_config.yaml
mkdir -p ~/.kube
cp kube_config_test_config.yaml ~/.kube/config
cd

wget "https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl" \
  -qO /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh --version ${HELM3_VERSION}
rm get_helm.sh

mkdir -p cert-manager && cd cert-manager
kubectl apply \
  --validate=false \
  -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml
kubectl create namespace cert-manager
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
    cert-manager \
    --namespace cert-manager \
    --version v0.12.0 \
    --set webhook.enabled=false \
    jetstack/cert-manager

sleep 2m

cat <<EOF > prod_issuer.yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: my-prod-issuer
spec:
  acme:
    email: ${CERT_MANAGER_ISSUER_EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: my-prod-issuer-secret-ref
    solvers:
    - http01:
       ingress:
         class: nginx
EOF

kubectl apply -f prod_issuer.yaml
cd

mkdir -p hetzner-csi && cd hetzner-csi
cat <<EOF > secret.yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-csi
  namespace: kube-system
stringData:
  token: $(cat ~/.htoken)
EOF

kubectl apply -f secret.yaml
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/v1.3.1/deploy/kubernetes/hcloud-csi.yml
cd

kubectl -n kube-system create secret generic hcloud --from-literal=token=$(cat ~/.htoken)
kubectl apply -f  https://raw.githubusercontent.com/hetznercloud/hcloud-cloud-controller-manager/master/deploy/v1.6.0.yaml

echo "NOTES:

Your cluster configured successfully! Here is the parameters and features:
- Docker version: ${DOCKER_VERSION}
- Kubernetes version: ${KUBERNETES_VERSION} (your cluster configured via RKE)
- Helm3 version: ${HELM3_VERSION}
- CNI: calico
- Ingress controller: Kubernetes Nginx
- Cert-manager: v0.0.12
- Hetzner CSI Driver: v1.3.1
- Hettzner Cloud Controller Manager: v1.6.0
- Metrics Server: enabled

The default storage-class is: hcloud-volumes. Minimum volume size: 10Gi.
To get the SSL certificate, add the next annotations to the Ingress:
# ingress_object.yaml
annotations:
  ingress.kubernetes.io/ssl-redirect: \"true\"
  kubernetes.io/ingress.class: nginx
  cert-manager.io/cluster-issuer: my-prod-issuer

Hetzner Cloud Token path: ~/.htoken
"