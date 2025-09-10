#!/bin/bash
# Dynamic Manifest Generator for MCP Atlassian
# Only includes environment variables for the authentication method being used

set -euo pipefail

# Configuration
DEPLOY_DIR="deploy"
TEMPLATES_DIR="${DEPLOY_DIR}/templates"
ARTIFACTS_DIR="${DEPLOY_DIR}/artifacts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
NAMESPACE="${NAMESPACE:-default}"
IMAGE_NAME="${IMAGE_NAME:-mcp-atlassian}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-quay.io}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-$USER}"
FULL_IMAGE="${REGISTRY}/${REGISTRY_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

MCP_PORT="${MCP_PORT:-8000}"
TRANSPORT="${TRANSPORT:-sse}"
READ_ONLY_MODE="${READ_ONLY_MODE:-true}"
MCP_VERBOSE="${MCP_VERBOSE:-true}"
ENABLE_CONFLUENCE="${ENABLE_CONFLUENCE:-false}"

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Dynamic manifest generator that only includes the authentication method you're using.

Required:
  --jira-url URL                  Jira instance URL

Authentication (choose one):
  --jira-pat TOKEN               Personal Access Token (recommended)
  --jira-api USERNAME TOKEN      API Token with username

Optional Confluence:
  --confluence-url URL           Confluence instance URL  
  --confluence-pat TOKEN         Confluence Personal Access Token
  --confluence-api USERNAME TOKEN Confluence API Token with username

Configuration:
  --namespace NAMESPACE          OpenShift namespace (default: default)
  --image IMAGE                  Full container image (default: auto-generated)
  --port PORT                    MCP port (default: 8000)
  --transport TYPE               Transport type (default: sse)
  --read-only BOOL               Read-only mode (default: true)
  --verbose BOOL                 Verbose logging (default: true)
  --enable-confluence BOOL       Enable Confluence (default: false)

Examples:
  # Personal Access Token (recommended)
  $0 --jira-url https://issues.redhat.com --jira-pat your_token

  # API Token  
  $0 --jira-url https://company.atlassian.net --jira-api user@company.com your_token

  # With Confluence
  $0 --jira-url https://issues.redhat.com --jira-pat jira_token \\
     --enable-confluence true --confluence-url https://confluence.company.com --confluence-pat conf_token

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --jira-url)
            JIRA_URL="$2"
            shift 2
            ;;
        --jira-pat)
            JIRA_PERSONAL_TOKEN="$2"
            JIRA_AUTH_METHOD="pat"
            shift 2
            ;;
        --jira-api)
            JIRA_USERNAME="$2"
            JIRA_API_TOKEN="$3"
            JIRA_AUTH_METHOD="api"
            shift 3
            ;;
        --confluence-url)
            CONFLUENCE_URL="$2"
            shift 2
            ;;
        --confluence-pat)
            CONFLUENCE_PERSONAL_TOKEN="$2"
            CONFLUENCE_AUTH_METHOD="pat"
            shift 2
            ;;
        --confluence-api)
            CONFLUENCE_USERNAME="$2"
            CONFLUENCE_API_TOKEN="$3"
            CONFLUENCE_AUTH_METHOD="api"
            shift 3
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --image)
            FULL_IMAGE="$2"
            shift 2
            ;;
        --port)
            MCP_PORT="$2"
            shift 2
            ;;
        --transport)
            TRANSPORT="$2"
            shift 2
            ;;
        --read-only)
            READ_ONLY_MODE="$2"
            shift 2
            ;;
        --verbose)
            MCP_VERBOSE="$2"
            shift 2
            ;;
        --enable-confluence)
            ENABLE_CONFLUENCE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validation
if [[ -z "${JIRA_URL:-}" ]]; then
    echo "Error: --jira-url is required"
    show_usage
    exit 1
fi

if [[ -z "${JIRA_AUTH_METHOD:-}" ]]; then
    echo "Error: Jira authentication is required (--jira-pat or --jira-api)"
    show_usage
    exit 1
fi

if [[ "$ENABLE_CONFLUENCE" == "true" ]]; then
    if [[ -z "${CONFLUENCE_URL:-}" ]]; then
        echo "Error: --confluence-url is required when Confluence is enabled"
        exit 1
    fi
    if [[ -z "${CONFLUENCE_AUTH_METHOD:-}" ]]; then
        echo "Error: Confluence authentication is required when Confluence is enabled"
        exit 1
    fi
fi

# Create artifacts directory
mkdir -p "$ARTIFACTS_DIR"

echo "Generating dynamic manifests for namespace $NAMESPACE..."

# Generate secrets.yaml with only required auth methods
cat > "$ARTIFACTS_DIR/secrets.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: mcp-atlassian-secrets
  namespace: $NAMESPACE
  labels:
    app: mcp-atlassian
    component: secrets
type: Opaque
stringData:
  # Jira Configuration (Required)
  JIRA_URL: "$JIRA_URL"
  
EOF

# Add Jira authentication based on method
if [[ "$JIRA_AUTH_METHOD" == "pat" ]]; then
    cat >> "$ARTIFACTS_DIR/secrets.yaml" << EOF
  # Jira Authentication: Personal Access Token
  JIRA_PERSONAL_TOKEN: "$JIRA_PERSONAL_TOKEN"
  
EOF
elif [[ "$JIRA_AUTH_METHOD" == "api" ]]; then
    cat >> "$ARTIFACTS_DIR/secrets.yaml" << EOF
  # Jira Authentication: API Token
  JIRA_USERNAME: "$JIRA_USERNAME"
  JIRA_API_TOKEN: "$JIRA_API_TOKEN"
  
EOF
fi

# Add Confluence configuration if enabled
if [[ "$ENABLE_CONFLUENCE" == "true" ]]; then
    cat >> "$ARTIFACTS_DIR/secrets.yaml" << EOF
  # Confluence Configuration
  CONFLUENCE_URL: "$CONFLUENCE_URL"
  
EOF
    
    if [[ "$CONFLUENCE_AUTH_METHOD" == "pat" ]]; then
        cat >> "$ARTIFACTS_DIR/secrets.yaml" << EOF
  # Confluence Authentication: Personal Access Token
  CONFLUENCE_PERSONAL_TOKEN: "$CONFLUENCE_PERSONAL_TOKEN"
  
EOF
    elif [[ "$CONFLUENCE_AUTH_METHOD" == "api" ]]; then
        cat >> "$ARTIFACTS_DIR/secrets.yaml" << EOF
  # Confluence Authentication: API Token
  CONFLUENCE_USERNAME: "$CONFLUENCE_USERNAME"
  CONFLUENCE_API_TOKEN: "$CONFLUENCE_API_TOKEN"
  
EOF
    fi
fi

# Add service configuration
cat >> "$ARTIFACTS_DIR/secrets.yaml" << EOF
  # Service Configuration
  ENABLE_CONFLUENCE: "$ENABLE_CONFLUENCE"
EOF

# Generate dynamic deployment.yaml with only required auth environment variables
echo "Generating deployment.yaml..."

cat > "$ARTIFACTS_DIR/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-atlassian
  namespace: $NAMESPACE
  labels:
    app: mcp-atlassian
    component: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mcp-atlassian
  template:
    metadata:
      labels:
        app: mcp-atlassian
    spec:
      serviceAccountName: default
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: mcp-atlassian
        image: $FULL_IMAGE
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: $MCP_PORT
          protocol: TCP
        env:
        # Transport Configuration
        - name: TRANSPORT
          value: "$TRANSPORT"
        - name: PORT
          value: "$MCP_PORT"
        - name: HOST
          value: "0.0.0.0"
        
        # Operational Configuration
        - name: READ_ONLY_MODE
          value: "$READ_ONLY_MODE"
        - name: MCP_VERBOSE
          value: "$MCP_VERBOSE"
        - name: MCP_LOGGING_STDOUT
          value: "true"
        
        # Jira Configuration (Required)
        - name: JIRA_URL
          valueFrom:
            secretKeyRef:
              name: mcp-atlassian-secrets
              key: JIRA_URL
        
EOF

# Add Jira authentication environment variables based on method
if [[ "$JIRA_AUTH_METHOD" == "pat" ]]; then
    cat >> "$ARTIFACTS_DIR/deployment.yaml" << EOF
        # Jira Authentication: Personal Access Token
        - name: JIRA_PERSONAL_TOKEN
          valueFrom:
            secretKeyRef:
              name: mcp-atlassian-secrets
              key: JIRA_PERSONAL_TOKEN
        
EOF
elif [[ "$JIRA_AUTH_METHOD" == "api" ]]; then
    cat >> "$ARTIFACTS_DIR/deployment.yaml" << EOF
        # Jira Authentication: API Token
        - name: JIRA_USERNAME
          valueFrom:
            secretKeyRef:
              name: mcp-atlassian-secrets
              key: JIRA_USERNAME
        - name: JIRA_API_TOKEN
          valueFrom:
            secretKeyRef:
              name: mcp-atlassian-secrets
              key: JIRA_API_TOKEN
        
EOF
fi

# Add Confluence configuration if enabled
if [[ "$ENABLE_CONFLUENCE" == "true" ]]; then
    cat >> "$ARTIFACTS_DIR/deployment.yaml" << EOF
        # Confluence Configuration
        - name: CONFLUENCE_URL
          valueFrom:
            secretKeyRef:
              name: mcp-atlassian-secrets
              key: CONFLUENCE_URL
        
EOF
    
    if [[ "$CONFLUENCE_AUTH_METHOD" == "pat" ]]; then
        cat >> "$ARTIFACTS_DIR/deployment.yaml" << EOF
        # Confluence Authentication: Personal Access Token
        - name: CONFLUENCE_PERSONAL_TOKEN
          valueFrom:
            secretKeyRef:
              name: mcp-atlassian-secrets
              key: CONFLUENCE_PERSONAL_TOKEN
        
EOF
    elif [[ "$CONFLUENCE_AUTH_METHOD" == "api" ]]; then
        cat >> "$ARTIFACTS_DIR/deployment.yaml" << EOF
        # Confluence Authentication: API Token
        - name: CONFLUENCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: mcp-atlassian-secrets
              key: CONFLUENCE_USERNAME
        - name: CONFLUENCE_API_TOKEN
          valueFrom:
            secretKeyRef:
              name: mcp-atlassian-secrets
              key: CONFLUENCE_API_TOKEN
        
EOF
    fi
fi

# Complete the deployment.yaml with remaining configuration
cat >> "$ARTIFACTS_DIR/deployment.yaml" << EOF
        # Health and readiness probes
        livenessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        
        # Resource limits and requests
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        
        # Security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          runAsGroup: 1000
          capabilities:
            drop:
            - ALL
        
        # Volume mounts (for OAuth token storage if needed)
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: oauth-cache
          mountPath: /home/app/.mcp-atlassian
      
      # Volumes
      volumes:
      - name: tmp
        emptyDir: {}
      - name: oauth-cache
        emptyDir: {}
      
      # Restart policy
      restartPolicy: Always
EOF

echo "Generating service.yaml..."
sed "s|{{NAMESPACE}}|$NAMESPACE|g; \
     s|{{MCP_PORT}}|$MCP_PORT|g" \
     "$TEMPLATES_DIR/service.yaml.template" > "$ARTIFACTS_DIR/service.yaml"

echo "Generating route.yaml..."
sed "s|{{NAMESPACE}}|$NAMESPACE|g" \
     "$TEMPLATES_DIR/route.yaml.template" > "$ARTIFACTS_DIR/route.yaml"

echo ""
echo "✅ Dynamic manifests generated successfully!"
echo ""
echo "Generated files:"
echo "  - $ARTIFACTS_DIR/secrets.yaml (only includes $JIRA_AUTH_METHOD auth for Jira"
if [[ "$ENABLE_CONFLUENCE" == "true" ]]; then
    echo "    and $CONFLUENCE_AUTH_METHOD auth for Confluence)"
else
    echo ")"
fi
echo "  - $ARTIFACTS_DIR/deployment.yaml"
echo "  - $ARTIFACTS_DIR/service.yaml"  
echo "  - $ARTIFACTS_DIR/route.yaml"
echo ""
echo "To deploy:"
echo "  oc apply -f $ARTIFACTS_DIR/ -n $NAMESPACE"
echo ""
echo "Or use the Makefile:"
echo "  make deploy-app NAMESPACE=$NAMESPACE"