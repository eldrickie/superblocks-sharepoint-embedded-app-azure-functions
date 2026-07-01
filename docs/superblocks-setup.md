# Superblocks Configuration

This guide walks through the Superblocks-side setup required before deploying the SharePoint embed proxy.

## Prerequisites

- A Superblocks organization (any plan that supports Embedded Apps)
- Admin access to the Superblocks org
- At least one application you want to embed

## Step 1: Create an Embed Access Token

The embed access token authenticates the proxy when creating session tokens for end users.

1. Log in to your Superblocks instance (e.g., `https://app.superblocks.com`)
2. Go to **Organization Settings** (gear icon in the bottom-left sidebar)
3. Navigate to **Embed** in the left menu
4. Click **Generate Token**
5. Give it a name (e.g., `SharePoint Embed Proxy`)
6. Copy the token — this is your `SUPERBLOCKS_EMBED_ACCESS_TOKEN`

> **Security:** This token has the ability to create sessions for any email address. Store it securely — only in Azure Function App settings or `.env` locally. Never commit it to source control.

## Step 2: Create a Group with `apps:view` Permission

Groups control which applications embed users can access. You need at least one group that grants `apps:view` on the applications you want to embed.

1. In Superblocks, go to **Organization Settings**
2. Navigate to **Groups** in the left menu
3. Click **Create Group**
4. Name it (e.g., `SharePoint Embed Users`)
5. Under **Permissions**, add the permission: **`apps:view`** for the specific application(s) you want to embed
   - You can scope this to specific apps or grant it org-wide
6. Copy the **Group ID** from the URL or group details — this is your `SUPERBLOCKS_GROUP_ID`

> **Tip:** You can specify multiple group IDs (comma-separated) in the env var if you want embed users to inherit permissions from multiple groups.

## Step 3: Get the Application ID

The application ID identifies which Superblocks app to render in the embed.

1. In Superblocks, navigate to the application you want to embed
2. The application ID is in the URL:
   ```
   https://app.superblocks.com/applications/YOUR_APPLICATION_ID/...
   ```
3. Alternatively, open the app settings and copy the ID from there
4. This is your `SUPERBLOCKS_APPLICATION_ID`

> **Note:** The application ID can also be passed dynamically via the `?appId=` query parameter on the embed URL, allowing a single proxy deployment to serve multiple applications.

## Step 4: Verify Embed is Enabled for the App

1. Open the application in Superblocks
2. Go to **App Settings** (gear icon)
3. Ensure **Embed** is enabled for this application
4. Note the embed URL format — the proxy constructs this automatically:
   ```
   https://app.superblocks.com/code-mode/embed/applications/YOUR_APPLICATION_ID
   ```

## Summary of Values

After completing these steps, you should have:

| Value | Env Variable | Example |
|---|---|---|
| Embed access token | `SUPERBLOCKS_EMBED_ACCESS_TOKEN` | `sbcXXXXXXXXXXXXXX...` |
| Group ID | `SUPERBLOCKS_GROUP_ID` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Application ID | `SUPERBLOCKS_APPLICATION_ID` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Superblocks URL | `SUPERBLOCKS_URL` | `https://app.superblocks.com` |

Add these to your `.env` file (for local development) or Azure Function App settings (for production).

## Next Steps

Once you have these values, proceed to:
- [Running locally](../README.md#running-locally) — to test the proxy on your machine
- [Deploying to Azure](./deployment.md) — to deploy and connect to SharePoint
