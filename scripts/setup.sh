#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="kagent-cluster"
NAMESPACE="kagent"

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
  kind create cluster --config cluster/kind-config.yaml
  info "Cluster created."
fi

kubectl config use-context "kind-${CLUSTER_NAME}"
info "kubectl context set."

# ── 4. Install kagent CRDs ────────────────────
info "Installing kagent CRDs..."
helm install kagent-crds \
  oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --wait || warn "kagent-crds already installed."

# ── 5. Install kagent ─────────────────────────
info "Installing kagent..."
helm install kagent \
  oci://ghcr.io/kagent-dev/kagent/helm/kagent \
  --namespace "${NAMESPACE}" \
  --set "providers.openAI.apiKey=${OPENAI_API_KEY}" \
  --wait

# ── 6. Deploy agents ──────────────────────────
info "Deploying agents..."
kubectl apply -f agents/

# ── 7. Deploy custom MCP server ───────────────
info "Building and deploying MCP server..."
cd mcp-servers/my-mcp-server
docker build -t my-mcp-server:latest .
kind load docker-image my-mcp-server:latest --name "${CLUSTER_NAME}"
kubectl apply -f kmcp.yaml
cd ../..

# ── 8. Done ───────────────────────────────────
info "Setup complete!"
echo ""
echo "  Dashboard  : kagent dashboard"
echo "  List agents: kagent get agent"
echo "  Invoke     : kagent invoke -t 'Why is my pod crashing?' --agent devops-agent"