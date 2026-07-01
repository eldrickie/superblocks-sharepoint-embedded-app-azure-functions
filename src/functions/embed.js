const { app } = require("@azure/functions");
const path = require("path");
const fs = require("fs");

const AZURE_CLIENT_ID = process.env.AZURE_CLIENT_ID;
const AZURE_TENANT_ID = process.env.AZURE_TENANT_ID;
const SUPERBLOCKS_URL = process.env.SUPERBLOCKS_URL || "https://app.superblocks.com";
const SUPERBLOCKS_APPLICATION_ID = process.env.SUPERBLOCKS_APPLICATION_ID;

let htmlTemplate;

function getHtml() {
  if (!htmlTemplate) {
    const filePath = path.join(__dirname, "../../public/index.html");
    htmlTemplate = fs.readFileSync(filePath, "utf8");
  }
  return htmlTemplate
    .replace("{{AZURE_CLIENT_ID}}", AZURE_CLIENT_ID)
    .replace("{{AZURE_TENANT_ID}}", AZURE_TENANT_ID)
    .replace("{{SUPERBLOCKS_URL}}", SUPERBLOCKS_URL)
    .replace("{{SUPERBLOCKS_APPLICATION_ID}}", SUPERBLOCKS_APPLICATION_ID || "");
}

app.http("embed", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "/",
  handler: async (request) => {
    return {
      status: 200,
      headers: {
        "Content-Type": "text/html",
        "Content-Security-Policy": "frame-ancestors *",
        "X-Frame-Options": "ALLOWALL",
      },
      body: getHtml(),
    };
  },
});
