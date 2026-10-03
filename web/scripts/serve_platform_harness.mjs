import { createServer } from "node:http";
import { readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const publicRoot = new URL("../public/", import.meta.url);
const fixtures = new URL("../tests/fixtures/", import.meta.url);
const routes = new Map([
  ["/", new URL("platform_controller.html", fixtures)],
  ["/platform_controller_review.mjs", new URL("platform_controller_review.mjs", fixtures)],
  ["/platform_context.mjs", new URL("platform_context.mjs", fixtures)],
  ["/vendor/nipplejs.mjs", new URL("vendor/nipplejs.mjs", publicRoot)],
]);
for (const name of readdirSync(publicRoot))
  if (/\.(js|css|json)$/.test(name)) routes.set("/" + name, new URL(name, publicRoot));
const server = createServer((request, response) => {
  const path = new URL(request.url, "http://localhost").pathname;
  const file = routes.get(path);
  if (request.method !== "GET" || !file) {
    response.writeHead(404);
    response.end();
    return;
  }
  const mime = file.pathname.endsWith(".html")
    ? "text/html"
    : file.pathname.endsWith(".css")
      ? "text/css"
      : file.pathname.endsWith(".json")
        ? "application/json"
        : "text/javascript";
  response.writeHead(200, {
    "Content-Type": mime + "; charset=utf-8",
    "Cache-Control": "no-store",
  });
  response.end(readFileSync(fileURLToPath(file)));
});
const port = Number(process.argv[2] || 18181);
server.listen(port, "127.0.0.1", () =>
  console.log(`Platform controller harness: http://127.0.0.1:${port}`),
);
