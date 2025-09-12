#!/bin/bash

# MCP Atlassian OpenShift Demo Script
# ==================================
# Demonstrates MCP Atlassian server deployment to OpenShift and Claude Code integration
# with production Jira access for real-world demonstration

set -e

# Colors for better presentation
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Production Jira settings
JIRA_URL="https://issues.redhat.com"
JIRA_PERSONAL_TOKEN=""  # Will be requested from user

# Demo functions
pause_for_input() {
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read -r
}

echo_command() {
    echo -e "\n${BLUE}About to run:${NC} ${GREEN}$1${NC}"
    pause_for_input
}

run_command() {
    echo -e "${YELLOW}Running:${NC} $1"
    eval "$1"
    echo ""
}

demo_step() {
    echo -e "\n${RED}=== $1 ===${NC}"
    echo "$2"
    pause_for_input
}

# Request JIRA token from user
if [ -z "$JIRA_PERSONAL_TOKEN" ]; then
    echo -e "${YELLOW}Please enter your Jira Personal Access Token:${NC}"
    echo -e "${BLUE}(This will be used to authenticate with $JIRA_URL)${NC}"
    read -s JIRA_PERSONAL_TOKEN
    echo ""
    
    if [ -z "$JIRA_PERSONAL_TOKEN" ]; then
        echo -e "${RED}Error: JIRA_PERSONAL_TOKEN is required${NC}"
        exit 1
    fi
fi

# Start the demo
clear

# Cleanup: Remove existing OpenShift deployment and MCP server
echo "🧹 Cleaning up any existing OpenShift deployment and MCP server..."

# Clean up OpenShift deployment
if oc get deployment mcp-atlassian >/dev/null 2>&1; then
    echo "Found existing OpenShift deployment, removing..."
    make undeploy 2>/dev/null || oc delete deployment,service,route -l app=mcp-atlassian 2>/dev/null || true
else
    echo "No existing OpenShift deployment found"
fi

# Clean up Claude Code MCP server
if claude mcp list 2>/dev/null | grep -q "ocp-atlassian"; then
    echo "Found existing Claude Code server, removing..."
    claude mcp remove ocp-atlassian || echo "Failed to remove existing server"
else
    echo "No existing Claude Code server found"
fi
sleep 2

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║              MCP ATLASSIAN OPENSHIFT DEMO                    ║
║            Production Deployment & Integration               ║
║                                                               ║
║  This demo shows:                                            ║
║  • OpenShift deployment with make deploy-dynamic            ║
║  • Production Jira integration                               ║
║  • Claude Code MCP server integration                       ║
║  • Real-time issue querying from Claude Code                ║
╚═══════════════════════════════════════════════════════════════╝
EOF

pause_for_input

# Step 1: Verify OpenShift connection
demo_step "STEP 1: Verify OpenShift Connection" \
"First, let's verify we're connected to the correct OpenShift cluster
and have the necessary permissions for deployment."

echo_command "oc whoami && oc project"
run_command "oc whoami && oc project"

# Step 2: Deploy to OpenShift using make deploy-dynamic
demo_step "STEP 2: Deploy MCP Atlassian to OpenShift" \
"Now we'll deploy MCP Atlassian to OpenShift using the dynamic deployment
method, which includes only the authentication method we're using."

echo_command "make deploy-dynamic \
  JIRA_URL=$JIRA_URL \
  JIRA_PERSONAL_TOKEN=***REDACTED***"

echo "Deploying MCP Atlassian with production Jira configuration..."
make deploy-dynamic \
  JIRA_URL="$JIRA_URL" \
  JIRA_PERSONAL_TOKEN="$JIRA_PERSONAL_TOKEN"

# Step 3: Verify deployment
demo_step "STEP 3: Verify Deployment Status" \
"Let's check that our deployment is running successfully and get the
external route URL for Claude Code integration."

echo_command "oc get pods,svc,route -l app=mcp-atlassian"
run_command "oc get pods,svc,route -l app=mcp-atlassian"

# Step 4: Get route and test connectivity
demo_step "STEP 4: Test MCP Server Connectivity" \
"We'll extract the route URL and test basic connectivity to ensure
the MCP server is responding correctly."

ROUTE_URL=$(oc get route mcp-atlassian -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -n "$ROUTE_URL" ]; then
    echo "Route URL: https://$ROUTE_URL"
    echo_command "curl -s -o /dev/null -w '%{http_code}\n' 'https://$ROUTE_URL/healthz'"
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}\n' "https://$ROUTE_URL/healthz" || echo "000")
    echo "HTTP Response: $HTTP_CODE"
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ MCP server is responding correctly!"
    else
        echo "⚠️  Server responding but may need a moment to fully initialize"
    fi
else
    echo "⚠️  Route not found - deployment may still be initializing"
fi

# Step 5: Add MCP server to Claude Code
demo_step "STEP 5: Add MCP Server to Claude Code" \
"Now we'll add the deployed MCP server to Claude Code so you can
interact with production Jira directly from your AI assistant."

if [ -n "$ROUTE_URL" ]; then
    MCP_URL="https://$ROUTE_URL/sse"
    echo "Adding MCP server with URL: $MCP_URL"
    
    echo_command "claude mcp add ocp-atlassian '$MCP_URL' --transport sse"
    claude mcp add ocp-atlassian "$MCP_URL" --transport sse || echo "✅ MCP server configuration attempted"
else
    echo "⚠️  Unable to determine route URL - you'll need to add the server manually"
    echo "Use: claude mcp add ocp-atlassian https://YOUR_ROUTE/sse --transport sse"
fi

# Step 6: Test with Claude Code
demo_step "STEP 6: Test Integration with Issue Lookup" \
"Finally, let's verify the integration works by attempting to query
a real production issue through Claude Code."

cat << 'EOF'

The MCP server is now deployed and configured with Claude Code!

You can now ask Claude Code to look up issues like:
"Look up issue RHOAIENG-34015"

This will demonstrate real-time Jira integration through your
OpenShift-deployed MCP server.

EOF

echo "To test the integration, you can now run:"
echo -e "${GREEN}claude${NC}"
echo "Then ask: 'Look up issue RHOAIENG-34015'"