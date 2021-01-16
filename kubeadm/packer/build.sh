#!/bin/bash -e

function pre_tasks () {
  local isEnvs=$(env | grep HCLOUD_TOKEN || true)
  if [[ -z ${isEnvs} ]]; then
    echo "=> hcloud token is not set. setting hcloud token as:"
    echo "  export HCLOUD_TOKEN=\$(cat ~/.hcloud_token)"
    export HCLOUD_TOKEN=$(cat ~/.hcloud_token)
  fi
}

function usage() {
  echo "Usage: bash $0 [flags]"
  echo "  -d    Docker version to install. Default: 19.03.8"
  echo "  -k    Kubernetes version to install. Default: v1.17.4"
  echo "  -c    Calicoctl version to install. Default: v3.14.0"
}

function main() {
  local docker_version=19.03.8
  local kubernetes_version=v1.17.4
  local calicoctl_version=v3.14.0
  local params=0

  while getopts "k:d:c:h" opt; do
    params=1
    case $opt in
      d)  docker_version=$OPTARG;;
      k)  kubernetes_version=$OPTARG;;
      c)  calicoctl_version=$OPTARG;;
      h)  usage
          exit 0;;
      esac
  done
  shift $((OPTIND -1))

  if [[ ${params} -eq 0 ]]; then
    usage
    exit 0
  fi
  
  pre_tasks

  local builded_json=$(jq -M -s \
    '{
      builders: (.[0].builders), 
      provisioners: (.[1].provisioners), 
      variables: (.[2].variables), 
      "sensitive-variables": (.[2]."sensitive-variables")
    }' \
    builder/hetzner.json \
    provisioner/ansible.json \
    variables.json)
  
  echo "${builded_json}" | packer build \
    -var="kubernetes_version=${kubernetes_version}" \
    -var="docker_version=${docker_version}" \
    -var="calicoctl_version=${calicoctl_version}" \
    -
}

main "$@"