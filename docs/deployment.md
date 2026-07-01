# Deploying the Azure Function

This guide covers deploying the Superblocks SharePoint Embed proxy to Azure Functions.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-tools?tabs=v4) (`func`)
- [Node.js 20+](https://nodejs.org/)
- An Azure subscription
- Superblocks embed credentials (see [superblocks-setup.md](./superblocks-setup.md) for how to generate them)

## Option A: Automated Deployment

The deploy script creates all Azure resources and deploys the code in one step.

1. Copy `.env.example` to `.env` and fill in your values:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. Authenticate with Azure:
   ```bash
   az login
   ```

3. Run the deploy script:
   ```bash
   ./scripts/deploy.sh --name my-sb-embed-proxy
   ```

   This will:
   - Create a resource group (`my-sb-embed-proxy-rg`)
   - Create a storage account
   - Create a Function App (Linux, Node.js 22, Consumption plan)
   - Set environment variables from your `.env` file
   - Deploy the function code

4. Note the output URL — you'll need it for the Entra ID and SharePoint configuration.

### Deploy script options

```
./scripts/deploy.sh --name NAME                    # required
                    --resource-group RG             # default: NAME-rg
                    --location REGION               # default: eastus2
                    --skip-create                   # skip resource creation, deploy code only
```

## Option B: Manual Deployment

### 1. Create the Function App

```bash
# Create resource group
az group create --name sb-embed-rg --location eastus2

# Create storage account
az storage account create \
  --name sbembedstore \
  --resource-group sb-embed-rg \
  --location eastus2 \
  --sku Standard_LRS

# Create Function App
az functionapp create \
  --name my-sb-embed-proxy \
  --resource-group sb-embed-rg \
  --storage-account sbembedstore \
  --consumption-plan-location eastus2 \
  --runtime node \
  --runtime-version 22 \
  --functions-version 4 \
  --os-type Linux
```

### 2. Set environment variables

```bash
az functionapp config appsettings set \
  --name my-sb-embed-proxy \
  --resource-group sb-embed-rg \
  --settings \
    AZURE_TENANT_ID="your-tenant-id" \
    AZURE_CLIENT_ID="your-client-id" \
    SUPERBLOCKS_EMBED_ACCESS_TOKEN="your-embed-token" \
    SUPERBLOCKS_GROUP_ID="your-group-id" \
    SUPERBLOCKS_URL="https://app.superblocks.com" \
    SUPERBLOCKS_APPLICATION_ID="your-app-id"
```

### 3. Deploy the code

```bash
npm install --production
func azure functionapp publish my-sb-embed-proxy --javascript
```

## Option C: Azure Portal

1. In the [Azure Portal](https://portal.azure.com), search **Function App** and click **Create**.
2. Configure:
   - **Runtime**: Node.js 22
   - **Plan**: Flex Consumption or Consumption
   - **OS**: Linux
3. After creation, go to **Settings > Environment variables** and add the variables from `.env.example`.
4. Deploy the code using the Azure Functions Core Tools:
   ```bash
   func azure functionapp publish YOUR_FUNCTION_APP_NAME --javascript
   ```

## Post-Deployment Configuration

After deploying, complete these steps:

### Entra ID App Registration

1. Go to the [Entra admin center](https://entra.microsoft.com)
2. **Applications > App registrations > New registration**
3. Name: `Superblocks Embed Proxy`
4. Supported account types: Single tenant
5. Click **Register**
6. Go to **Authentication > Add a platform > Single-page application**
7. Set the redirect URI to your Function App URL (e.g., `https://my-sb-embed-proxy.azurewebsites.net/`)
8. Click **Configure**
9. Go to the admin consent URL to grant `User.Read`:
   ```
   https://login.microsoftonline.com/YOUR_TENANT_ID/adminconsent?client_id=YOUR_CLIENT_ID
   ```

### SharePoint Configuration

1. Go to your SharePoint site
2. Navigate to **Site Settings > HTML Field Security** (classic settings page: `/_layouts/15/HtmlFieldSecurity.aspx`)
3. Add your Function App domain to the allowed list
4. On your SharePoint page, add an **Embed** web part with this iframe code:
   ```html
   <iframe src="https://YOUR_FUNCTION_APP_URL/?appId=YOUR_APP_ID&domainHint=YOUR_DOMAIN" width="100%" height="800" frameborder="0" style="border:none;"></iframe>
   ```
