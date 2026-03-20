# kagent-project

Deploy AI Agents and MCP Servers on Kubernetes using [kagent](https://kagent.dev).

---

## What is this project?

This project sets up a fully working AI agent platform on a local Kubernetes cluster using **kind**. It uses **kagent** to deploy autonomous AI agents that can actually interact with your cluster — reading logs, listing pods, checking RBAC, and fetching web content — powered by OpenAI.

```
User → kagent UI → Agent (LLM) → MCP Tool Server → Kubernetes Cluster
```

---

## Stack

| Component | Tool | Version |
|---|---|---|
| Local Kubernetes | kind | v1.35.0 |
| Agent framework | kagent | v0.7.23 |
| LLM provider | OpenAI | gpt-4.1-mini |
| Custom MCP server | FastMCP | Python 3.11 |
| Package manager | Helm | v3+ |

---

## Folder Structure

```
kagent-project/
├── README.md                          ← you are here
├── .gitignore
│
├── cluster/
│   ├── kind-config.yaml               ← kind cluster (1 control-plane + 2 workers)
│   └── kagent-values.yaml             ← Helm values for kagent
│
├── agents/
│   ├── devops-agent.yaml              ← DevOps troubleshooting agent
│   ├── security-agent.yaml            ← CVE / RBAC security agent
│   └── fetch-agent.yaml               ← Web fetch agent (custom MCP)
│
├── mcp-servers/
│   └── my-mcp-server/
│       ├── main.py                    ← FastMCP server (fetch, pod logs, list pods)
│       ├── requirements.txt
│       ├── Dockerfile
│       ├── kmcp.yaml                  ← MCPServer CRD
│       └── remote-mcp-server.yaml     ← RemoteMCPServer CRD (wires agent to server)
│
└── scripts/
    ├── setup.sh                       ← One-shot setup script
    └── teardown.sh                    ← Delete the cluster
```

---

## Prerequisites

Install these tools before running:

```bash
# macOS
brew install kind kubectl helm docker

# Verify
kind version
kubectl version --client
helm version
docker --version
```

Also install the kagent CLI:

```bash
curl https://raw.githubusercontent.com/kagent-dev/kagent/refs/heads/main/scripts/get-kagent | bash
```

---

## Quick Start

### 1. Set your OpenAI API key

```bash
export OPENAI_API_KEY="sk-proj-your-key-here"
```

> Never hardcode API keys in files. Always use environment variables.

### 2. Run setup

```bash
cd kagent-project
bash scripts/setup.sh
```

This single script will:
- Create a kind cluster (1 control-plane + 2 workers)
- Install kagent CRDs and the kagent platform via Helm
- Deploy all three custom agents
- Build and load the custom MCP server Docker image
- Deploy the MCP server and wire it up

### 3. Open the dashboard

```bash
kagent dashboard
# Opens http://localhost:8082
```

### 4. Invoke agents via CLI

```bash
# DevOps agent
kagent invoke -t "How many nodes does my cluster have?" --agent devops-agent

# Security agent
kagent invoke -t "Check RBAC roles in the kagent namespace" --agent security-agent

# Fetch agent
kagent invoke -t "Fetch https://example.com" --agent fetch-agent
```

---

## Agents

### devops-agent
Troubleshoots Kubernetes workloads. Can diagnose CrashLoopBackOff errors, analyze logs, check resource usage, and inspect deployments.

**Tools:** `kagent-tool-server` (kubectl, helm, prometheus)

```bash
kagent invoke -t "Why is my pod crashing?" --agent devops-agent
```

### security-agent
Audits cluster security. Checks RBAC roles, scans for misconfigurations, and reviews network policies.

**Tools:** `kagent-tool-server` (kubectl, cilium)

```bash
kagent invoke -t "Audit RBAC in the default namespace" --agent security-agent
```

### fetch-agent
Fetches and summarizes web content using a custom MCP server.

**Tools:** `my-mcp-server-remote` (fetch_url, get_pod_logs, list_pods)

```bash
kagent invoke -t "Fetch https://example.com" --agent fetch-agent
```

---

## MCP Servers

### Built-in (shipped with kagent)

| Name | URL | Tools |
|---|---|---|
| `kagent-tool-server` | `http://kagent-tools.kagent:8084/mcp` | kubectl, helm, istio, cilium, argo |
| `kagent-grafana-mcp` | `http://kagent-grafana-mcp.kagent:8000/mcp` | Grafana dashboards |

### Custom (built in this project)

| Name | URL | Tools |
|---|---|---|
| `my-mcp-server-remote` | `http://my-mcp-server.kagent:8000/mcp` | fetch_url, get_pod_logs, list_pods |

---

## How It Works

### MCP (Model Context Protocol)
Gives agents **tools** — functions they can call to take real actions.

```
Agent (LLM) → calls k8s_get_resources tool
               ↓
           MCP server executes kubectl against cluster
               ↓
           real data returned to agent
               ↓
           agent reasons on real data → answers
```

### A2A (Agent2Agent Protocol)
Gives agents **teammates** — other agents they can delegate tasks to.

```
Orchestrator agent
  ├── A2A → Security agent  → MCP → k8s tools
  ├── A2A → Cost agent      → MCP → prometheus tools
  └── A2A → Network agent   → MCP → istio tools
```

> MCP = agent gets tools. A2A = agent gets teammates.

---

## Useful Commands

```bash
# Check all agents
kubectl get agents -n kagent

# Check all pods
kubectl get pods -n kagent

# Check MCP servers
kubectl get mcpservers -n kagent
kubectl get remotemcpservers -n kagent

# Check model config
kubectl get modelconfigs -n kagent

# View agent logs
kubectl logs -n kagent deployment/devops-agent

# Restart agents
kubectl rollout restart deployment/devops-agent deployment/security-agent deployment/fetch-agent -n kagent
```

---

## Teardown

```bash
bash scripts/teardown.sh
```

This deletes the entire kind cluster and everything inside it.

---

## References

| Resource | URL |
|---|---|
| kagent docs | https://kagent.dev/docs |
| kagent GitHub | https://github.com/kagent-dev/kagent |
| MCP spec | https://modelcontextprotocol.io |
| A2A spec | https://google.github.io/A2A |
| kind docs | https://kind.sigs.k8s.io |