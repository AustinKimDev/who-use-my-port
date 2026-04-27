# whoport

`whoport` is the local CLI bridge for AI-assisted development tools.

It writes usage registrations to:

```text
~/Library/Application Support/WhoUseMyPort/registry.json
```

The macOS app reads that same registry and combines it with live `lsof` scanner data.

## Common Commands

Check whether a port is occupied or registered:

```sh
bin/whoport check 3000
```

Register usage before an AI tool starts a dev server:

```sh
bin/whoport reserve 3000 \
  --tool codex \
  --project "$PWD" \
  --command "pnpm dev" \
  --purpose "Next.js dev server"
```

Release the registration:

```sh
bin/whoport release 3000 --tool codex --project "$PWD"
```

Run a command while registering its usage. The registration is removed when the command exits:

```sh
bin/whoport wrap 3000 \
  --tool codex \
  --project "$PWD" \
  --purpose "web dev server" \
  -- pnpm dev
```

Print a small shell helper:

```sh
bin/whoport hook
```

Then use:

```sh
export WHOPORT_TOOL=codex
whoport_run 3000 pnpm dev
```

## AI Integration Pattern

An AI terminal should call `whoport check <port>` before starting a server.

If the port is available, it should run the server through `whoport wrap`.

If the port is occupied, it should inspect the returned JSON:

- `processes`: live local listeners from `lsof`
- `registrations`: AI/tool/project usage metadata
- `status`: `available`, `reserved`, or `occupied`

That gives the AI enough context to decide whether to reuse a server, choose another port, or ask before terminating a process.
