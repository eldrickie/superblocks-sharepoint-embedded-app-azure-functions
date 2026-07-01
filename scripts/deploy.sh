#!/usr/bin/env bash
#
# Deploy the Superblocks SharePoint Embed proxy to Azure Functions.
#
# Prerequisites:
#   - Azure CLI (az) installed and authenticated
#   - Azure Functions Core Tools (func) installed
#   - A .env file with required configuration (see .env.example)
#
# Usage:
#   ./scripts/deploy.sh                          # interactive — prompts for missing values
#   ./scripts/deploy.sh --name my-func-app       # specify the Function App name
#   ./scripts/deploy.sh --name my-func-app \
#     --resource-group my-rg \
#     --location eastus2                          # fully automated
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
FUNC_APP_NAME=""
RESOURCE_GROUP=""
LOCATION="eastus2"
RUNTIME="node"
RUNTIME_VERSION="22"
SKIP_CREATE=false

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --name NAME              Azure Function App name (required)"
  echo "  --resource-group RG      Azure Resource Group (created if missing)"
  echo "  --location LOC           Azure region (default: eastus2)"
  echo "  --skip-create            Skip resource creation, only deploy code"
  echo "  -h, --help               Show this help"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) FUNC_APP_NAME="$2"; shift 2 ;;
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    --skip-create) SKIP_CREATE=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Prompt for required values if not provided
if [[ -z "$FUNC_APP_NAME" ]]; then
  read -rp "Function App name: " FUNC_APP_NAME
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
  RESOURCE_GROUP="${FUNC_APP_NAME}-rg"
  echo "Using resource group: $RESOURCE_GROUP"
fi

# Verify Azure CLI is authenticated
echo "Checking Azure CLI authentication..."
az account show > /dev/null 2>&1 || {
  echo "Not logged in. Running: az login --use-device-code"
  az login --use-device-code
}

# Load .env if present
ENV_FILE="${PROJECT_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo "Loading configuration from .env..."
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ "$SKIP_CREATE" == false ]]; then
  # Create resource group
  echo "Creating resource group: $RESOURCE_GROUP in $LOCATION..."
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none

  # Create storage account (required for Azure Functions)
  STORAGE_NAME=$(echo "${FUNC_APP_NAME}store" | tr -d '-' | head -c 24)
  echo "Creating storage account: $STORAGE_NAME..."
  az storage account create \
    --name "$STORAGE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --output none

  # Create Function App
  echo "Creating Function App: $FUNC_APP_NAME..."
  az functionapp create \
    --name "$FUNC_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --storage-account "$STORAGE_NAME" \
    --consumption-plan-location "$LOCATION" \
    --runtime "$RUNTIME" \
    --runtime-version "$RUNTIME_VERSION" \
    --functions-version 4 \
    --os-type Linux \
    --output none

  # Configure environment variables
  echo "Setting application settings..."
  SETTINGS=""
  [[ -n "${AZURE_TENANT_ID:-}" ]] && SETTINGS+="AZURE_TENANT_ID=$AZURE_TENANT_ID "
  [[ -n "${AZURE_CLIENT_ID:-}" ]] && SETTINGS+="AZURE_CLIENT_ID=$AZURE_CLIENT_ID "
  [[ -n "${SUPERBLOCKS_EMBED_ACCESS_TOKEN:-}" ]] && SETTINGS+="SUPERBLOCKS_EMBED_ACCESS_TOKEN=$SUPERBLOCKS_EMBED_ACCESS_TOKEN "
  [[ -n "${SUPERBLOCKS_GROUP_ID:-}" ]] && SETTINGS+="SUPERBLOCKS_GROUP_ID=$SUPERBLOCKS_GROUP_ID "
  [[ -n "${SUPERBLOCKS_URL:-}" ]] && SETTINGS+="SUPERBLOCKS_URL=$SUPERBLOCKS_URL "
  [[ -n "${SUPERBLOCKS_APPLICATION_ID:-}" ]] && SETTINGS+="SUPERBLOCKS_APPLICATION_ID=$SUPERBLOCKS_APPLICATION_ID "

  if [[ -n "$SETTINGS" ]]; then
    # shellcheck disable=SC2086
    az functionapp config appsettings set \
      --name "$FUNC_APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --settings $SETTINGS \
      --output none
  fi
fi

# Deploy code
echo "Deploying function code..."
cd "$PROJECT_DIR"
npm install --production
func azure functionapp publish "$FUNC_APP_NAME" --javascript

# Get the deployed URL
HOSTNAME=$(az functionapp show \
  --name "$FUNC_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "defaultHostName" \
  --output tsv)

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Function App URL: https://$HOSTNAME"
echo "Health check:     https://$HOSTNAME/health"
echo "Token endpoint:   https://$HOSTNAME/oauth2/token"
echo "Embed page:       https://$HOSTNAME/"
echo ""
echo "Next steps:"
echo "  1. Register an Entra ID app and set the redirect URI to: https://$HOSTNAME/"
echo "  2. Grant admin consent for User.Read"
echo "  3. Add $HOSTNAME to SharePoint HTML Field Security allow-list"
echo "  4. Add an Embed web part to your SharePoint page pointing to: https://$HOSTNAME/?appId=YOUR_APP_ID"
