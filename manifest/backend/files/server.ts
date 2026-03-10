// Bun HTTP server — returns testing response.
// Mounted into the container via ConfigMap; run with: bun run /app/server.ts

// Start time used to calculate phase in the periodic failure simulation.
const START_TIME_MS = Date.now();

function accessLog(req: Request, res: Response): void {
  const now = new Date().toISOString();
  const method = req.method;
  const url = new URL(req.url);
  const path = url.pathname + url.search;
  const via = req.headers.get("via") ?? "-";
  console.log(`${now} ${method} ${path} ${res.status} via=${via}`);
}

// Wraps a route handler with access logging. Supports async handlers.
function withLog(handler: (req: Request) => Response | Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    const res = await handler(req);
    accessLog(req, res);
    return res;
  };
}

const server = Bun.serve({
  port: 3000,
  routes: {
    // Health check endpoint — always 200, never cached.
    "/healthz": withLog(
      () =>
        new Response("ok", {
          status: 200,
          headers: {
            "Content-Type": "text/plain; charset=utf-8",
            "Cache-Control": "no-store",
          },
        }),
    ),

    // Main handler — simulates a periodic backend failure.
    // Cycle: first OK_SECONDS seconds succeed (200), next ERROR_SECONDS seconds
    // fail with ERROR_DELAY_MS delay and 500 status, then the cycle repeats.
    "/*": withLog(async () => {
      const OK_SECONDS = 20;
      const ERROR_SECONDS = 60;
      const ERROR_DELAY_MS = 5000;

      const elapsed = Math.floor((Date.now() - START_TIME_MS) / 1000);
      const phase = elapsed % (OK_SECONDS + ERROR_SECONDS);
      if (phase >= OK_SECONDS) {
        await Bun.sleep(ERROR_DELAY_MS);
        return new Response("Internal Server Error", {
          status: 500,
          headers: {
            "Content-Type": "text/plain; charset=utf-8",
            "Cache-Control": "no-store",
          },
        });
      }

      return new Response(new Date().toISOString(), {
        status: 200,
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "public, max-age=10",
        },
      });
    }),
  },
});

console.log(`Listening on http://0.0.0.0:${server.port}`);

// Graceful shutdown on SIGTERM (sent by Kubernetes before pod termination).
// server.stop(false) stops accepting new connections but waits for in-flight
// requests to complete before exiting.
process.on("SIGTERM", async () => {
  console.log("SIGTERM received, shutting down gracefully");
  await server.stop(false);
  process.exit(0);
});
