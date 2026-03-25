#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<USAGE
Usage: ./scripts/rg.sh <create|destroy>

Commands:
  create   Create/update the Synapse lab resource group with Terraform
  destroy  Destroy the Synapse lab resource group with Terraform
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

command="$1"

cd "$ROOT_DIR"

case "$command" in
  create)
    terraform init
    terraform apply -auto-approve
    ;;
  destroy)
    terraform init
    terraform destroy -auto-approve
    ;;
  *)
    usage
    exit 1
    ;;
esac
