#!/usr/bin/env bash
set -euo pipefail

# Tear down the entire kagent kind cluster

CLUSTER_NAME="kagent-cluster"

echo "Deleting kind cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "${CLUSTER_NAME}"
echo "Done. Cluster deleted."