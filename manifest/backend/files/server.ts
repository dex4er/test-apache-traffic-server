// Bun HTTP server — returns testing response.
// Mounted into the container via ConfigMap; run with: bun run /app/server.ts

function accessLog(req: Request, res: Response): void {
	const now = new Date().toISOString();
	const method = req.method;
	const url = new URL(req.url);
	const path = url.pathname + url.search;
	const via = req.headers.get("via") ?? "-";
	console.log(`${now} ${method} ${path} ${res.status} via=${via}`);
}

// Wraps a route handler with access logging.
function withLog(handler: (req: Request) => Response) {
	return (req: Request): Response => {
		const res = handler(req);
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

		"/*": withLog(
			() =>
				new Response(new Date().toISOString(), {
					status: 200,
					headers: {
						"Content-Type": "text/plain; charset=utf-8",
						"Cache-Control": "public, max-age=10",
					},
				}),
		),
	},
});

console.log(`Listening on http://0.0.0.0:${server.port}`);
