const { app } = require("@azure/functions");
const jwt = require("jsonwebtoken");
const jwksClient = require("jwks-rsa");

const AZURE_TENANT_ID = process.env.AZURE_TENANT_ID;
const AZURE_CLIENT_ID = process.env.AZURE_CLIENT_ID;
const SUPERBLOCKS_EMBED_ACCESS_TOKEN = process.env.SUPERBLOCKS_EMBED_ACCESS_TOKEN;
const SUPERBLOCKS_GROUP_ID = process.env.SUPERBLOCKS_GROUP_ID;
const SUPERBLOCKS_URL = process.env.SUPERBLOCKS_URL || "https://app.superblocks.com";

const jwks = jwksClient({
  jwksUri: `https://login.microsoftonline.com/${AZURE_TENANT_ID}/discovery/v2.0/keys`,
  cache: true,
  rateLimit: true,
});

function getSigningKey(header, callback) {
  jwks.getSigningKey(header.kid, (err, key) => {
    if (err) return callback(err);
    callback(null, key.getPublicKey());
  });
}

function verifyEntraToken(token) {
  return new Promise((resolve, reject) => {
    jwt.verify(
      token,
      getSigningKey,
      {
        audience: AZURE_CLIENT_ID,
        issuer: `https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0`,
      },
      (err, decoded) => {
        if (err) reject(err);
        else resolve(decoded);
      }
    );
  });
}

app.http("token", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "oauth2/token",
  handler: async (request, context) => {
    try {
      const authHeader = request.headers.get("authorization") || "";
      const entraToken = authHeader.replace("Bearer ", "");

      if (!entraToken) {
        return {
          status: 401,
          jsonBody: { error: "No authorization token provided" },
        };
      }

      const claims = await verifyEntraToken(entraToken);
      const email = claims.preferred_username || claims.email;
      const name = claims.name || email;

      if (!email) {
        return {
          status: 400,
          jsonBody: { error: "Could not extract email from Entra token" },
        };
      }

      const tokenRequestBody = { email, name };

      if (SUPERBLOCKS_GROUP_ID) {
        tokenRequestBody.groupIds = SUPERBLOCKS_GROUP_ID.split(",").map((id) =>
          id.trim()
        );
      }

      const baseUrl = new URL(SUPERBLOCKS_URL).origin;
      const response = await fetch(`${baseUrl}/api/v1/public/token`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${SUPERBLOCKS_EMBED_ACCESS_TOKEN}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(tokenRequestBody),
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.message || `Superblocks API error (${response.status})`);
      }

      const data = await response.json();
      return { jsonBody: data };
    } catch (err) {
      context.log("Token exchange error:", err.message);
      return {
        status: 401,
        jsonBody: { error: "Authentication failed", message: err.message },
      };
    }
  },
});
