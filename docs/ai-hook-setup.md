# AI Hook Setup

MCP is not required for the first useful integration. The simplest setup is:

1. AI checks a port before starting a dev server.
2. AI starts the dev server through `whoport wrap`.
3. The app reads the shared registry and visualizes owner/project/command.

## Shell Hook

Source the hook:

```sh
export WHOPORT_TOOL=codex
export WHOPORT_BIN="$PWD/bin/whoport"
. "$PWD/hooks/whoport-hook.sh"
```

Run a dev server with tracking:

```sh
whoport_run 3000 -- pnpm dev
```

Run as a specific tool:

```sh
whoport_run_as cursor 5173 -- npm run dev
```

Check before deciding:

```sh
whoport_check 3000
```

Reserve manually when a tool will start the process itself:

```sh
whoport_reserve 3000 --command "pnpm dev" --purpose "Next.js dev server"
```

Release:

```sh
whoport_release 3000
```

## Install Into A Shell Profile

```sh
scripts/install-whoport-hook.sh ~/.zshrc
```

For AI-specific terminals, prefer setting the tool name explicitly in that session:

```sh
export WHOPORT_TOOL=codex
```

```sh
export WHOPORT_TOOL=claude
```

```sh
export WHOPORT_TOOL=cursor
```

## Suggested Agent Instruction

Use this as a short instruction block for Codex, Claude Code, Cursor, or another local coding agent:

```text
Before starting a local dev server, check the intended port with:
  whoport_check <port>

If the port is available or only reserved by this same project, start the server with:
  whoport_run <port> -- <command...>

If the port is occupied by another project/tool, do not kill it automatically.
Report the owner/project/process and either reuse it, choose another port, or ask first.

When a process is started without whoport_run, register it manually with:
  whoport_reserve <port> --command "<command>" --purpose "<purpose>"
```

## Practical Examples

Next.js:

```sh
whoport_run 3000 -- pnpm dev
```

Vite:

```sh
whoport_run 5173 -- npm run dev
```

FastAPI:

```sh
whoport_run 8000 -- uvicorn app.main:app --reload --port 8000
```

Rails:

```sh
whoport_run 3000 -- bin/rails server -p 3000
```
