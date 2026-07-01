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
   - **Plan**: **Consumption** (Linux)
   - **OS**: Linux
3. After creation, go to **Settings > Environment variables** and add the variables from `.env.example`.
4. Deploy the code using the Azure Functions Core Tools:
   ```bash
   func azure functionapp publish YOUR_FUNCTION_APP_NAME --javascript
   ```

> **Important:** Do **not** use the Flex Consumption plan. The Azure Functions Core Tools (`func`) CLI is incompatible with Flex Consumption — it injects build settings (`SCM_DO_BUILD_DURING_DEPLOYMENT`, `ENABLE_ORYX_BUILD`) that Flex Consumption rejects. Use the standard **Consumption** plan instead.

## Post-Deployment Configuration

After deploying, complete these steps:

### Entra ID App Registration

1. Go to the [Entra admin center](https://entra.microsoft.com)
2. **Applications > App registrations > New registration**
3. Name: `Superblocks Embed Proxy`
4. Supported account types: **Single tenant** (Accounts in this organizational directory only)
5. Click **Register**
6. Note the **Application (client) ID** and **Directory (tenant) ID** from the Overview page — these are your `AZURE_CLIENT_ID` and `AZURE_TENANT_ID`
7. Go to **Authentication** in the left menu
8. Click **Add a platform** → select **Single-page application**
9. Set the redirect URI to your Function App URL **with a trailing slash**:
   ```
   https://my-sb-embed-proxy.azurewebsites.net/
   ```
   > **Important:** The redirect URI must exactly match `window.location.origin + "/"`. Include the trailing slash. The platform type must be "Single-page application" (not "Web") — this enables the PKCE flow that MSAL.js requires.
10. Click **Configure**
11. Go to **API permissions** in the left menu → verify `User.Read` (Microsoft Graph, Delegated) is listed. If not, click **Add a permission > Microsoft Graph > Delegated > User.Read**.
12. Click **Grant admin consent for [Your Org]** (blue button at the top of the permissions list)

### SharePoint Configuration

#### Allow the domain in HTML Field Security

SharePoint blocks iframes from domains not on its allow list. You must add your Function App domain.

> **Note:** Microsoft has removed the HTML Field Security setting from the SharePoint admin center UI. It is only accessible via a direct URL.

1. Navigate directly to this URL (replace `yoursite` with your SharePoint site URL):
   ```
   https://yoursite.sharepoint.com/_layouts/15/HtmlFieldSecurity.aspx
   ```
   For example: `https://contoso.sharepoint.com/_layouts/15/HtmlFieldSecurity.aspx`

2. In the text box, add your Function App domain (e.g., `my-sb-embed-proxy.azurewebsites.net`)
3. Click **OK** to save

> **Alternative (PowerShell):** If the UI page doesn't load, you can set it via Azure CLI + CSOM:
> ```bash
> TOKEN=$(az account get-access-token --resource "https://yoursite-admin.sharepoint.com" --query accessToken -o tsv)
> curl -X POST "https://yoursite-admin.sharepoint.com/_vti_bin/client.svc/ProcessQuery" \
>   -H "Authorization: Bearer $TOKEN" -H "Content-Type: text/xml" \
>   -d '<Request AddExpandoFieldTypeSuffix="true" SchemaVersion="15.0.0.0" LibraryVersion="16.0.0.0" ApplicationName="curl" xmlns="http://schemas.microsoft.com/sharepoint/clientquery/2009"><Actions><ObjectPath Id="1" ObjectPathId="0" /><SetProperty Id="2" ObjectPathId="0" Name="AllowedDomainListForHtmlField"><Parameter Type="String">my-sb-embed-proxy.azurewebsites.net</Parameter></SetProperty><Method Name="Update" Id="3" ObjectPathId="0" /></Actions><ObjectPaths><Constructor Id="0" TypeId="{268004ae-ef6b-4e9b-8425-127220d84719}" /></ObjectPaths></Request>'
> ```

#### Add the Embed web part to your SharePoint page

1. Edit a SharePoint page
2. Add an **Embed** web part
3. Paste this iframe code (replace the placeholder values):
   ```html
   <iframe src="https://YOUR_FUNCTION_APP_URL/?appId=YOUR_APP_ID&domainHint=YOUR_TENANT_DOMAIN" width="100%" height="800" frameborder="0" style="border:none;"></iframe>
   ```
   Example:
   ```html
   <iframe src="https://my-sb-embed-proxy.azurewebsites.net/?appId=34db2209-bd80-4b18-b5f6-5f23808fcdc9&domainHint=contoso.onmicrosoft.com" width="100%" height="800" frameborder="0" style="border:none;"></iframe>
   ```
4. **Publish** the page (the embed only works on the published page, not in edit mode)

#### User experience

- **First visit:** Users see a "Sign in with Microsoft" button. They click it, a popup authenticates them instantly (since they're already logged into SharePoint), and the app loads.
- **Subsequent visits:** Authentication is cached in `sessionStorage`, so the app loads immediately without the button.
- **No `loginHint` needed:** The popup handles any user in the tenant — no hardcoded emails required.
