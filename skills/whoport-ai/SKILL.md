---
name: whoport-ai
description: Use whoport before starting local development servers so ports are checked, registered, and visible in Who Use My Port.
---

# whoport-ai

Use this skill whenever you are about to start, restart, or inspect a local development server.
AI tools must register every service they start through `whoport wrap` or `whoport reserve`; do not start a dev server directly with `pnpm dev`, `npm run dev`, `uvicorn`, `rails server`, `python -m http.server`, or similar commands.

## Goal

Keep local dev ports visible to the user and avoid accidental port conflicts.

## Required Workflow

1. Identify the intended port from the command, framework default, env var, or user request.
2. Run:

   ```sh
   "${WHOPORT_BIN:-/Users/jidong/workspace/side/who-use-my-port/bin/whoport}" check <port>
   ```

3. Interpret the JSON:
   - `available`: proceed.
   - `reserved`: check whether the registration is the same project/tool.
   - `occupied`: inspect `processes` and `registrations`.

4. If another project/tool owns the port, do not kill it automatically. Explain the owner and choose a different port or ask the user.

5. Start the server through:

   ```sh
   "${WHOPORT_BIN:-/Users/jidong/workspace/side/who-use-my-port/bin/whoport}" wrap <port> --tool <tool-name> --project "$PWD" -- <command...>
   ```

   This is mandatory for AI-started services.

6. If the server must be started by another mechanism, register manually:

   ```sh
   "${WHOPORT_BIN:-/Users/jidong/workspace/side/who-use-my-port/bin/whoport}" reserve <port> --tool <tool-name> --project "$PWD" --command "<command>" --purpose "<purpose>"
   ```

7. Release manual registrations when the server is no longer relevant:

   ```sh
   "${WHOPORT_BIN:-/Users/jidong/workspace/side/who-use-my-port/bin/whoport}" release <port> --tool <tool-name> --project "$PWD"
   ```

## Tool Names

Use stable lowercase tool names:

- `codex`
- `claude`
- `cursor`
- `manual`

## Examples

Next.js:

```sh
"${WHOPORT_BIN:-/Users/jidong/workspace/side/who-use-my-port/bin/whoport}" wrap 3000 --tool codex --project "$PWD" -- pnpm dev
```

Vite:

```sh
"${WHOPORT_BIN:-/Users/jidong/workspace/side/who-use-my-port/bin/whoport}" wrap 5173 --tool codex --project "$PWD" -- npm run dev
```

FastAPI:

```sh
"${WHOPORT_BIN:-/Users/jidong/workspace/side/who-use-my-port/bin/whoport}" wrap 8000 --tool codex --project "$PWD" -- uvicorn app.main:app --reload --port 8000
```
