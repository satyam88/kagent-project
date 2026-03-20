from fastmcp import FastMCP
import subprocess

mcp = FastMCP("my-mcp-server")


@mcp.tool()
def fetch_url(url: str) -> str:
    """Fetch the contents of a webpage by URL"""
    import urllib.request
    with urllib.request.urlopen(url) as response:
        return response.read().decode("utf-8")[:5000]


@mcp.tool()
def get_pod_logs(pod_name: str, namespace: str = "default") -> str:
    """Fetch logs from a Kubernetes pod"""
    result = subprocess.run(
        ["kubectl", "logs", pod_name, "-n", namespace],
        capture_output=True, text=True
    )
    return result.stdout or result.stderr


@mcp.tool()
def list_pods(namespace: str = "default") -> str:
    """List all pods in a namespace"""
    result = subprocess.run(
        ["kubectl", "get", "pods", "-n", namespace, "-o", "wide"],
        capture_output=True, text=True
    )
    return result.stdout or result.stderr


if __name__ == "__main__":
    mcp.run(transport="streamable-http", host="0.0.0.0", port=8000, path="/mcp")
