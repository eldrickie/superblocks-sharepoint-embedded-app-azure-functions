# Superblocks Embed — SharePoint + Entra ID SSO

An Azure Function BFF (Backend for Frontend) proxy that enables embedding Superblocks applications in SharePoint pages with single sign-on via Microsoft Entra ID.

Users authenticate once via a popup (since SharePoint iframes block third-party cookies for silent SSO), and then the Superblocks app renders. On subsequent visits, the cached session makes authentication instant.

## How it works

```
SharePoint Page
└── Embed web part (iframe)
    └── Azure Function (this project)
        ├── GET /             → Serves HTML page with MSAL.js
        ├── GET /oauth2/token → Validates Entra token, returns Superblocks session token
        └── GET /health       → Health check
```

1. The SharePoint Embed web part loads the Azure Function URL in an iframe.
2. MSAL.js attempts silent authentication (`ssoSilent` → `acquireTokenSilent`).
3. If silent auth fails (expected in cross-origin iframes due to third-party cookie blocking), a **"Sign in with Microsoft"** button appears.
4. The user clicks the button → a popup opens → since the user is already signed into Microsoft (they're on SharePoint), the popup authenticates instantly and closes.
5. The page sends the Entra ID token to `/oauth2/token`.
6. The function validates the token against Microsoft's JWKS endpoint, extracts the user's email and name.
7. The function calls `POST /api/v1/public/token` on the Superblocks API with the user's identity.
8. Superblocks returns a session token and the Embed SDK renders the app.

> **Note:** On subsequent visits, `acquireTokenSilent` uses the cached session from step 4, so the user won't see the button again (until the session expires).

## Prerequisites

- [Node.js 20+](https://nodejs.org/)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-tools?tabs=v4)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (for deployment)
- A Microsoft 365 tenant with SharePoint Online
- A Superblocks org with an Embed access token (see [docs/superblocks-setup.md](docs/superblocks-setup.md))

## Running locally

1. Clone this repository:
   ```bash
   git clone https://github.com/superblocksteam/superblocks-embed-sharepoint.git
   cd superblocks-embed-sharepoint
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Copy the example settings and fill in your values:
   ```bash
   cp .env.example .env
   cp local.settings.json.example local.settings.json
   # Edit both files with your configuration
   ```

4. Start the local development server:
   ```bash
   npm start
   ```

   The server starts at `http://localhost:7071`. Endpoints:
   - `http://localhost:7071/` — Embed page
   - `http://localhost:7071/oauth2/token` — Token exchange
   - `http://localhost:7071/health` — Health check

   > **Note:** SSO via `ssoSilent()` requires the page to be served from a domain registered as a redirect URI in your Entra ID app registration. For local testing, add `http://localhost:7071/` as a redirect URI or use `loginHint`/`domainHint` query parameters.

## Deploying to Azure

See [docs/deployment.md](docs/deployment.md) for full instructions. Quick start:

```bash
cp .env.example .env
# Edit .env with your configuration

az login
./scripts/deploy.sh --name my-sb-embed-proxy
```

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `SUPERBLOCKS_URL` | No | `https://app.superblocks.com` | Superblocks instance URL |
| `SUPERBLOCKS_APPLICATION_ID` | No | — | Default application ID (can be overridden via `?appId=` query param) |
| `SUPERBLOCKS_EMBED_ACCESS_TOKEN` | Yes | — | Embed access token from Superblocks org settings |
| `SUPERBLOCKS_GROUP_ID` | Yes | — | Group ID with `apps:view` permission (comma-separated for multiple) |
| `AZURE_TENANT_ID` | Yes | — | Entra ID (Azure AD) tenant ID |
| `AZURE_CLIENT_ID` | Yes | — | Entra ID app registration client ID |

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/` | Serves the embed HTML page with MSAL.js authentication |
| `GET` | `/oauth2/token` | Validates Entra ID token and returns a Superblocks session token |
| `GET` | `/health` | Returns `{"status": "ok"}` |

## Query parameters

The embed page accepts these query parameters:

| Parameter | Description |
|---|---|
| `appId` | Superblocks application ID (overrides `SUPERBLOCKS_APPLICATION_ID` env var) |
| `loginHint` | User's email for MSAL — disambiguates when multiple Microsoft accounts are present |
| `domainHint` | Tenant domain for MSAL — use when all users share a domain (e.g., `contoso.onmicrosoft.com`) |
| `sbBaseUrl` | Override the Superblocks URL |

## Related links

- [Superblocks Embedded Apps Docs](https://docs.superblocks.com/applications/embedded-apps/)
- [Superblocks Embed SDK](https://www.npmjs.com/package/@superblocksteam/embed)
- [MSAL.js Documentation](https://learn.microsoft.com/en-us/entra/identity-platform/msal-js-initializing-client-applications)
- [Azure Functions Documentation](https://learn.microsoft.com/en-us/azure/azure-functions/)
