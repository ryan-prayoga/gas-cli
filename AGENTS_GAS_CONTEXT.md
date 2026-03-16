# AGENTS_GAS_CONTEXT.md

## Purpose

This file is a quick context guide for AI coding agents working inside a project that uses `gas` CLI.

Assume this project uses `gas` as the main workflow for build, run, restart, and VPS deployment unless the repo says otherwise.

This document is intentionally project-portable. You can copy it into another repo that already uses `gas`.

## What GAS CLI Is

`gas` is a CLI helper for building, running, and deploying apps on Ubuntu or VPS environments.

In a typical project, `gas` is responsible for:

- detecting the app stack
- building the project
- starting or restarting the app with PM2
- verifying runtime health
- saving app metadata for future operations
- generating and applying Nginx deploy config

If this repo includes this file, assume `gas` is part of the expected operational workflow.

## When Agents Should Care About GAS

Pay attention to `gas` when the user asks to:

- build the project
- restart a running service
- rebuild after code changes
- deploy to a VPS or domain
- change PM2 name, runtime port, or domain mapping
- inspect logs or app runtime status
- create or update CI/CD automation

If `gas` is already part of the project workflow, do not bypass it without a clear reason.

## Core Commands

- `gas build`
  Build the app, choose a run strategy, start or restart PM2, verify runtime, and save metadata.

- `gas info`
  Show stored metadata for the current app or a selected app.

- `gas list`
  List apps known by `gas` from the global metadata database.

- `gas restart`
  Restart an app managed by PM2, usually by PM2 name.

- `gas logs`
  View PM2 logs for an app.

- `gas rebuild`
  Re-run build using previously saved metadata when available.

- `gas deploy`
  Generate and apply Nginx deployment config using app metadata.

- `gas doctor`
  Check whether the system has the expected runtime tools and dependencies.

## Short Build Workflow

The normal `gas build` flow is:

1. detect the project stack
2. choose the build and run strategy
3. build the project
4. start or restart the PM2 process
5. verify runtime health
6. save metadata to the global database

The metadata database is usually stored at:

`~/.config/gas/apps.db`

## Stack Detection

`gas` can automatically detect common project types, including:

- Go
- SvelteKit
- Next.js
- Nuxt
- Vite
- generic Node app

Do not assume every Node-based project runs the same way. Let stack detection and build strategy guide the command choice.

## Common Build Strategies

`gas` commonly works with these strategies:

- `ecosystem`
  Use an existing PM2 ecosystem config if the repo already defines runtime details there.

- `node-entry`
  Run a built server entry file directly with Node.

- `npm-preview`
  Use `npm run preview` when the project exposes a preview server and no stronger production entry is available.

- `npm-start`
  Use `npm run start` when the project defines a production start script.

- `auto`
  Let `gas` detect the best available strategy and verify it.

Prefer `auto` unless the repo clearly requires a fixed strategy.

## CI/CD Mode

For automation, agents should prefer:

- `--no-ui`
- `--yes`
- explicit and deterministic flags such as `--type`, `--pm2-name`, `--port`, and `--strategy`

In CI/CD, avoid relying on interactive prompts or hidden defaults.

In many pipelines, `gas build` already handles PM2 start or restart. Do not add a separate manual PM2 restart unless there is a clear operational reason.

## Realistic CI/CD Commands

Frontend build:

```bash
gas build --no-ui --type node-web --pm2-name web --port 4001 --strategy auto --git-pull no --yes
```

Backend build:

```bash
gas build --no-ui --type go --pm2-name api --port 4000 --git-pull no --yes
```

Rebuild from saved metadata:

```bash
gas rebuild --no-ui --yes
```

Deploy a domain:

```bash
gas deploy --no-ui --app web --domain app.example.com --mode single-app --ssl certbot-nginx --yes
```

Split frontend and backend:

```bash
gas deploy --no-ui --frontend web --backend api --domain app.example.com --mode frontend-backend-split --uploads /home/ubuntu/app/uploads --ssl certbot-nginx --yes
```

## PM2 and Port Awareness

Before changing runtime config, agents should check:

- `pm2_name`
- assigned `port`
- current logs
- runtime health check result
- existing metadata in `~/.config/gas/apps.db`

This matters because `gas` uses saved metadata to keep future rebuild, restart, info, and deploy actions consistent.

Do not rename PM2 processes or change ports blindly. First confirm what the app is already using.

Useful checks:

```bash
gas info
gas list
gas logs <pm2-name>
gas restart <pm2-name>
```

## Nginx and Deploy Awareness

If the project uses `gas deploy`, agents should think in terms of deploy mode, not only raw Nginx files.

Before changing deploy config, consider:

- the main domain
- the route `/`
- the route `/api/`
- uploads or static aliases
- SSL and Certbot requirements
- whether the deploy is `single-app`, `frontend-backend-split`, or another mode

Do not edit Nginx config casually without understanding how the current deploy mode maps routes and upstreams.

For example:

- `single-app` usually sends `/` to one app
- `frontend-backend-split` usually sends `/` to frontend and `/api/` to backend
- static files may be served via alias paths such as `/uploads/`

If SSL uses Certbot, domain DNS and port 80/443 reachability also matter.

## Rules for Future Agents

- Do not jump straight to custom manual scripts if `gas` is already the project workflow.
- Prefer `gas build` and `gas deploy` over ad hoc PM2 or Nginx commands.
- Do not ignore metadata in `~/.config/gas/apps.db`.
- Do not assume all Node projects should use the same runtime command.
- Check stack and strategy first.
- For CI/CD, use non-interactive mode.
- If the repo has `USING_GAS.md` or `GAS_BUILD_CICD.md`, prioritize those files too.

## Short Examples

Deploy frontend app:

```bash
gas deploy --no-ui --app web --domain app.example.com --mode single-app --ssl certbot-nginx --yes
```

Deploy backend with frontend split:

```bash
gas deploy --no-ui --frontend web --backend api --domain app.example.com --mode frontend-backend-split --yes
```

Check logs:

```bash
gas logs web
```

Restart app:

```bash
gas restart web
```

## Practical Default

If a user says "build this app", "restart the service", or "deploy to VPS", first check whether the repo already expects `gas`.

If yes, use the `gas` workflow first and only fall back to manual PM2 or Nginx handling when the repo explicitly requires it.
