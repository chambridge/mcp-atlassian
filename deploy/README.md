# MCP Atlassian - OpenShift Deployment Guide

This guide provides step-by-step instructions for deploying the MCP Atlassian server to an OpenShift cluster and configuring it for use with Claude Code or other MCP clients.

## Prerequisites

### Required Tools
- **OpenShift CLI (`oc`)**: [Installation guide](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- **Container runtime**: Docker or Podman
- **Make**: Build automation tool

### Required Information
- **Jira Configuration** (Required):
  - Jira URL (e.g., `https://your-company.atlassian.net` or `https://jira.your-company.com`)
  
  **Choose ONE authentication method:**
  - **Personal Access Token** (Recommended for Server/DC, also works for Cloud):
    - Jira Personal Access Token ([Generate in Jira profile settings](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/))
  - **API Token** (Cloud only):
    - Jira API Token ([Generate here](https://id.atlassian.com/manage-profile/security/api-tokens))
    - Jira Username/Email

- **Confluence Configuration** (Optional):
  - Only needed if `ENABLE_CONFLUENCE=true`
  - Confluence URL (e.g., `https://your-company.atlassian.net/wiki` or `https://confluence.your-company.com`)
  - Confluence authentication (PAT or API Token + Username)

### OpenShift Access
- OpenShift cluster access with deployment permissions
- Target namespace (default: `default`)

## Quick Start Deployment

### 1. Login to OpenShift
```bash
oc login https://your-openshift-cluster.com
```

### 2. Deploy MCP Atlassian (Jira-Only, Default)

#### Option A: Personal Access Token (Recommended)
```bash
# Deploy Jira-only with PAT (read-only by default)
make deploy \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_personal_access_token

# Enable write operations
make deploy \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_personal_access_token \
  READ_ONLY_MODE=false
```

#### Option B: API Token (Cloud)
```bash
# Deploy Jira-only with API Token (read-only by default)
make deploy \
  JIRA_URL=https://your-company.atlassian.net \
  JIRA_USERNAME=your.email@company.com \
  JIRA_API_TOKEN=your_jira_api_token

# Enable write operations
make deploy \
  JIRA_URL=https://your-company.atlassian.net \
  JIRA_USERNAME=your.email@company.com \
  JIRA_API_TOKEN=your_jira_api_token \
  READ_ONLY_MODE=false
```

### 3. Deploy with Confluence (Optional)

```bash
# Add Confluence support with PAT
make deploy \
  ENABLE_CONFLUENCE=true \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_pat \
  CONFLUENCE_URL=https://confluence.your-company.com \
  CONFLUENCE_PERSONAL_TOKEN=your_confluence_pat

# Mixed authentication (PAT for Jira, API Token for Confluence)
make deploy \
  ENABLE_CONFLUENCE=true \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_pat \
  CONFLUENCE_URL=https://your-company.atlassian.net/wiki \
  CONFLUENCE_USERNAME=your.email@company.com \
  CONFLUENCE_API_TOKEN=your_confluence_api_token
```

### 4. Deploy to Custom Namespace
```bash
# Deploy to specific namespace
make deploy \
  NAMESPACE=mcp-atlassian \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_token
```

### 5. Get the Route URL
```bash
make status
# Or directly:
oc get route mcp-atlassian -n default -o jsonpath='{.spec.host}'
```

## Dynamic Deployment (Recommended for Clean Auth)

**New in this version**: Dynamic deployment only includes the authentication method you're actually using, preventing authentication confusion that can cause "JSON decode errors" in Claude Code.

### Why Use Dynamic Deployment?
- **Cleaner Configuration**: Only includes environment variables for your chosen auth method
- **Prevents Auth Confusion**: Eliminates empty auth variables that can confuse the MCP server
- **Better Debugging**: Easier to troubleshoot authentication issues
- **Claude Code Compatible**: Reduces connection issues with MCP clients

### Dynamic Deployment Options

#### Option A: Personal Access Token (Recommended)
```bash
# Deploy Jira-only with PAT (read-only by default)
make deploy-dynamic \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_personal_access_token

# Enable write operations
make deploy-dynamic \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_personal_access_token \
  READ_ONLY_MODE=false
```

#### Option B: API Token (Cloud)
```bash
# Deploy Jira-only with API Token (read-only by default)
make deploy-dynamic \
  JIRA_URL=https://your-company.atlassian.net \
  JIRA_USERNAME=your.email@company.com \
  JIRA_API_TOKEN=your_jira_api_token

# Enable write operations
make deploy-dynamic \
  JIRA_URL=https://your-company.atlassian.net \
  JIRA_USERNAME=your.email@company.com \
  JIRA_API_TOKEN=your_jira_api_token \
  READ_ONLY_MODE=false
```

#### Option C: Manual Script Usage
For advanced configurations, use the script directly:
```bash
# Personal Access Token
./scripts/generate-dynamic-manifests.sh \
  --jira-url https://jira.your-company.com \
  --jira-pat your_token \
  --namespace default \
  --read-only true

# API Token
./scripts/generate-dynamic-manifests.sh \
  --jira-url https://company.atlassian.net \
  --jira-api user@company.com your_token \
  --enable-confluence true \
  --confluence-url https://confluence.company.com \
  --confluence-pat confluence_token

# Deploy generated manifests
oc apply -f deploy/artifacts/ -n default
```

## Step-by-Step Deployment

### Step 1: Prepare Your Environment

1. **Clone and Navigate to Repository**:
   ```bash
   cd mcp-atlassian
   ```

2. **Verify Prerequisites**:
   ```bash
   # Check OpenShift access
   oc whoami

   # Check container runtime
   make help
   ```

### Step 2: Configure Authentication

#### Option A: Personal Access Token (Recommended)

**For Server/Data Center or Cloud:**
1. Go to your Jira/Confluence profile → Personal Access Tokens
2. Create tokens with appropriate permissions (read or read/write depending on your needs)
3. PATs work for both Server/Data Center and Cloud deployments

#### Option B: API Token Authentication (Cloud Only)

**For Atlassian Cloud:**
1. Go to [Atlassian API Tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Create tokens and note your email addresses
3. API tokens require your username/email for authentication

### Step 3: Build and Push Container Image

```bash
# Build the container image
make build

# Push to your registry (optional - uses ghcr.io/sooperset/mcp-atlassian by default)
make push REGISTRY=your-registry.com REGISTRY_USERNAME=youruser
```

### Step 4: Deploy to OpenShift

#### Deploy with Personal Access Token (Recommended)
```bash
# Jira-only, read-only deployment (secure default)
make deploy \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_pat

# Jira-only with write operations enabled
make deploy \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_pat \
  READ_ONLY_MODE=false
```

#### Deploy with API Token (Cloud)
```bash
# Jira-only, read-only deployment
make deploy \
  JIRA_URL=https://your-company.atlassian.net \
  JIRA_USERNAME=your.email@company.com \
  JIRA_API_TOKEN=your_jira_token

# With write operations enabled
make deploy \
  JIRA_URL=https://your-company.atlassian.net \
  JIRA_USERNAME=your.email@company.com \
  JIRA_API_TOKEN=your_jira_token \
  READ_ONLY_MODE=false
```

#### Deploy with Confluence Support
```bash
# Full deployment with both services
make deploy \
  ENABLE_CONFLUENCE=true \
  NAMESPACE=mcp-systems \
  MCP_PORT=9000 \
  READ_ONLY_MODE=false \
  JIRA_URL=https://jira.your-company.com \
  JIRA_PERSONAL_TOKEN=your_jira_pat \
  CONFLUENCE_URL=https://confluence.your-company.com \
  CONFLUENCE_PERSONAL_TOKEN=your_confluence_pat
```

### Step 5: Verify Deployment

```bash
# Check deployment status
make status

# View logs
make logs

# Test health endpoint
curl https://$(oc get route mcp-atlassian -o jsonpath='{.spec.host}')/healthz
```

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NAMESPACE` | `default` | OpenShift namespace |
| `MCP_PORT` | `8000` | Port for MCP server |
| `TRANSPORT` | `sse` | Transport type (`sse`, `streamable-http`) |
| `READ_ONLY_MODE` | `true` | **Security default**: Disable write operations |
| `MCP_VERBOSE` | `true` | Enable verbose logging |
| `ENABLE_CONFLUENCE` | `false` | **Jira-only default**: Enable Confluence support |

### Authentication Configuration

| Method | Variables Required | Use Case |
|--------|-------------------|----------|
| **Personal Access Token** | `JIRA_PERSONAL_TOKEN` | Server/DC or Cloud (Recommended) |
| **API Token** | `JIRA_USERNAME` + `JIRA_API_TOKEN` | Cloud only |
| **Confluence PAT** | `CONFLUENCE_PERSONAL_TOKEN` | Optional, when `ENABLE_CONFLUENCE=true` |
| **Confluence API Token** | `CONFLUENCE_USERNAME` + `CONFLUENCE_API_TOKEN` | Optional, when `ENABLE_CONFLUENCE=true` |

### Custom Image Configuration

```bash
make deploy \
  REGISTRY=quay.io \
  REGISTRY_USERNAME=myorg \
  IMAGE_NAME=mcp-atlassian \
  IMAGE_TAG=v1.0.0 \
  # ... other parameters
```

## Using with Claude Code

### Option 1: MCP Add Command (Recommended - Simple Setup)

Use the `mcp add` command when the MCP server is deployed with fixed authentication credentials:

```bash
# Get your route URL first
ROUTE_URL=$(oc get route mcp-atlassian -o jsonpath='{.spec.host}')

# Add to Claude Code with SSE transport type (REQUIRED for proper connection)
claude mcp add ocp-atlassian --transport sse https://$ROUTE_URL/sse
```

**Important Notes**: 
- The `--transport sse` flag is **required** for proper connection to OpenShift-deployed MCP servers
- This works when the MCP server is deployed with authentication credentials baked into the deployment (via JIRA_PERSONAL_TOKEN or JIRA_API_TOKEN environment variables)
- All Claude Code users will share the same Atlassian credentials configured in the deployment
- If you get "JSON decode errors", use `make deploy-dynamic` instead of `make deploy` to avoid authentication confusion

### Option 2: Manual JSON Configuration (Simple - No Per-User Authentication)

Alternatively, configure Claude Code manually by editing the configuration file when using shared credentials:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "https://your-mcp-route.apps.openshift.com/sse"
    }
  }
}
```

### Option 3: Per-User Authentication (Advanced Multi-User Setup)

**Important**: The current deployment templates configure authentication at the pod level. For true per-user authentication, you would need to modify the deployment to accept authentication headers and pass them through to Atlassian APIs. 

For development/testing of per-user authentication:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "https://your-mcp-route.apps.openshift.com/sse",
      "headers": {
        "X-Jira-Personal-Token": "YOUR_PERSONAL_ACCESS_TOKEN",
        "X-Jira-Username": "your.email@company.com"
      }
    }
  }
}
```

**Note**: This requires modifying the MCP server to read authentication from request headers instead of environment variables. The current implementation uses environment variables for security and simplicity.

## Advanced Configuration

### Custom Secrets Management

1. **Edit the secrets template** (`templates/secrets.yaml.template`):
   ```yaml
   # Add custom environment variables
   CONFLUENCE_SPACES_FILTER: "DEV,TEAM,DOC"
   JIRA_PROJECTS_FILTER: "PROJ,DEVOPS"
   ```

2. **Deploy with custom secrets**:
   ```bash
   make generate-manifests
   # Edit artifacts/secrets.yaml manually
   make deploy-app
   ```

### OAuth 2.0 Configuration

For OAuth setup, uncomment OAuth sections in templates and provide:

```bash
make deploy \
  ATLASSIAN_OAUTH_CLIENT_ID=your_client_id \
  ATLASSIAN_OAUTH_CLIENT_SECRET=your_client_secret \
  ATLASSIAN_OAUTH_CLOUD_ID=your_cloud_id \
  # ... other OAuth parameters
```

### Resource Scaling

Edit `templates/deployment.yaml.template` to adjust:
- Replica count
- Resource requests/limits
- Health check timeouts

## Troubleshooting

### Common Issues

#### 1. Authentication Failures

**JSON Decode Error when using Claude Code:**
If you get a JSON decode error when Claude Code tries to connect, this is often caused by authentication confusion due to empty environment variables for unused authentication methods.

```bash
# Check if the MCP server was deployed with authentication
oc get secret mcp-atlassian-secrets -n default -o yaml

# Look for authentication-related environment variables (check for empty values)
oc get deployment mcp-atlassian -n default -o yaml | grep -A 10 -B 10 -i "jira\|confluence"

# Check logs for auth errors
make logs | grep -i "auth\|401\|403\|invalid\|token"

# Test the health endpoint directly
curl https://$(oc get route mcp-atlassian -o jsonpath='{.spec.host}')/healthz
```

**Recommended Solution**: Use dynamic deployment to avoid authentication confusion:
```bash
# Undeploy current version
make undeploy

# Redeploy with dynamic deployment (only includes auth method you're using)
make deploy-dynamic JIRA_URL=... JIRA_PERSONAL_TOKEN=...
# OR
make deploy-dynamic JIRA_URL=... JIRA_USERNAME=... JIRA_API_TOKEN=...
```

**Alternative Solution**: If using regular deployment, ensure you deployed with either:
- Personal Access Token: `make deploy JIRA_URL=... JIRA_PERSONAL_TOKEN=...`
- API Token: `make deploy JIRA_URL=... JIRA_USERNAME=... JIRA_API_TOKEN=...`

#### 2. Network Connectivity
```bash
# Test from inside the cluster
oc run test-pod --image=curlimages/curl --rm -it -- \
  curl -v http://mcp-atlassian.default.svc.cluster.local/healthz
```

#### 3. Route Access Issues
```bash
# Check route configuration
oc describe route mcp-atlassian

# Test external access
curl -v https://$(oc get route mcp-atlassian -o jsonpath='{.spec.host}')/healthz
```

### Debug Commands

```bash
# View all resources
oc get all -l app=mcp-atlassian

# Describe deployment for events
oc describe deployment mcp-atlassian

# Get detailed pod information
oc describe pod -l app=mcp-atlassian

# Check service endpoints
oc get endpoints mcp-atlassian
```

### Log Analysis

```bash
# Follow logs with timestamp
oc logs -l app=mcp-atlassian --timestamps=true -f

# Get logs from previous pod (if crashed)
oc logs -l app=mcp-atlassian --previous

# Filter for specific issues
make logs | grep -E "ERROR|WARN|Failed"
```

## Maintenance

### Updating the Deployment

```bash
# Update with new image
make deploy IMAGE_TAG=v2.0.0

# Update configuration
make deploy READ_ONLY_MODE=true MCP_VERBOSE=false
```

### Scaling

```bash
# Scale replicas
oc scale deployment mcp-atlassian --replicas=3
```

### Backup and Recovery

```bash
# Export current configuration
oc get all,secrets,routes -l app=mcp-atlassian -o yaml > mcp-atlassian-backup.yaml

# Restore from backup
oc apply -f mcp-atlassian-backup.yaml
```

## Cleanup

### Remove Deployment

```bash
# Remove all resources
make undeploy

# Remove from specific namespace
make undeploy NAMESPACE=mcp-atlassian
```

### Remove Generated Files

```bash
# Clean up local artifacts
rm -rf deploy/artifacts/

# Clean up container images
make clean
```

## Security Considerations

1. **Use HTTPS**: The route template enables TLS termination
2. **Secure Secrets**: API tokens are stored in OpenShift secrets
3. **Network Policies**: Consider implementing network policies for isolation
4. **RBAC**: Use minimal required permissions for the service account
5. **Regular Updates**: Keep the container image updated

## Support

For issues and questions:
- Check the main [MCP Atlassian README](../README.md)
- Review [troubleshooting section](#troubleshooting) above
- Check OpenShift cluster logs and events
- Verify Atlassian API connectivity and permissions
