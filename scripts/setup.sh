#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="kagent-cluster"
NAMESPACE="kagent"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 1. Preflight ──────────────────────────────
info "Checking required tools..."
for tool in kind kubectl helm docker; do
  command -v "$tool" &>/dev/null || error "$tool not found."
done
info "All tools present."

# ── 2. API key check ──────────────────────────
[[ -z "${OPENAI_API_KEY:-}" ]] && error "OPENAI_API_KEY is not set. Run: export OPENAI_API_KEY=sk-..."
info "OpenAI API key found."

# ── 3. Create kind cluster ────────────────────
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "Cluster '${CLUSTER_NAME}' already exists — skipping."
else
  info "Creating kind cluster..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${ROOT_DIR}/cluster/kind-config.yaml"
  info "Cluster created."
fi

kubectl config use-context "kind-${CLUSTER_NAME}"
info "kubectl context set."

# ── 4. Install kagent CRDs ────────────────────
info "Installing/upgrading kagent CRDs..."
helm upgrade --install kagent-crds \
  oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --wait

# ── 5. Install kagent ─────────────────────────
info "Installing/upgrading kagent..."
helm upgrade --install kagent \
  oci://ghcr.io/kagent-dev/kagent/helm/kagent \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set "providers.openAI.apiKey=${OPENAI_API_KEY}" \
  --wait

# ── 6. Deploy agents ──────────────────────────
info "Deploying agents..."
kubectl apply -f "${ROOT_DIR}/agents/"

# ── 7. Deploy custom MCP server ───────────────
info "Building and deploying MCP server..."
MCP_DIR="${ROOT_DIR}/mcp-servers/my-mcp-server"
MCP_MANIFEST="${MCP_DIR}/remote-mcp-server.yaml"

cd "${MCP_DIR}"

info "Building Docker image..."
docker build -t my-mcp-server:latest .

info "Loading image into kind cluster..."
kind load docker-image my-mcp-server:latest --name "${CLUSTER_NAME}"

info "Applying MCP manifest..."
[[ -f "${MCP_MANIFEST}" ]] || error "Manifest not found: ${MCP_MANIFEST}"
kubectl apply -f "${MCP_MANIFEST}"

cd "${ROOT_DIR}"

# ── 8. Verification ───────────────────────────
info "Verifying deployment..."
kubectl get pods -n "${NAMESPACE}" || true
kubectl get agents -n "${NAMESPACE}" || true
kubectl get remotemcpservers -n "${NAMESPACE}" || true

# ── 9. Done ───────────────────────────────────
info "Setup complete!"
echo ""
echo "  Dashboard  : kagent dashboard"
echo "  List agents: kubectl get agents -n ${NAMESPACE}"
echo "  Invoke     : kagent invoke -t 'Why is my pod crashing?' --agent devops-agent"