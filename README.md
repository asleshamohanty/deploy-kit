# DeployKit

Deploy modern Node.js applications with a single command.

DeployKit is a modular deployment framework for Express + React applications
running on a single Linux server. It automates builds, PM2 process
management, Nginx validation, HTTPS verification, health checks, logging,
and rollbacks while keeping every deployment transparent and reproducible.

## Why this exists

Most "deploy scripts" are a single `deploy.sh` that rebuilds everything,
every time, with no validation and no way back if something breaks.
DeployKit instead:

- Diffs the git history to figure out what *actually* changed, and only
  rebuilds/restarts the affected parts (see `lib/git.sh`).
- Refuses to reload Nginx on a broken config (`lib/nginx.sh`).
- Runs retrying health checks before declaring success (`lib/health.sh`).
- Keeps timestamped releases so a bad deploy is one command to undo
  (`lib/rollback.sh`).
- Logs every run to `logs/deploy-<timestamp>.log`.

DeployKit isn't designed to hide the deployment process. Every step is
visible, validated, and logged so you always know what is happening and
why. The goal is automation without sacrificing transparency.

## Features

- Incremental deployments using Git change detection
- Smart frontend/backend rebuilds
- PM2 process lifecycle management
- Nginx validation before reload
- Automatic HTTP health verification
- SSL certificate status reporting
- Timestamped deployment logs
- Rollback-ready release snapshots
- Config-driven architecture
- Interactive diagnostics (`doctor`, `status`)

## Design Principles

DeployKit follows a few core principles:

- Fail fast instead of silently continuing.
- Never reload production services without validation.
- Only perform work that is actually necessary.
- Keep every deployment reproducible.
- Prefer explicit configuration over hidden defaults.
- Make debugging easier than deployment.

## How it fits together

```
Git Push
    │
    ▼
deploykit deploy
    │
    ▼
Load Config
    │
    ▼
Git Pull
    │
    ▼
Detect Changes
 ┌──────┴───────┐
 │              │
 ▼              ▼
Backend      Frontend
 │              │
 ▼              ▼
PM2        Vite Build
 │              │
 └──────┬───────┘
        ▼
 Validate Nginx
        │
        ▼
 Health Checks
        │
        ▼
 Deployment Complete
```

## Quick start

```bash
cp templates/deploy.config.example.sh deploy.config.sh
# edit deploy.config.sh with your project's paths/domain/port

./bin/deploykit deploy --dry-run   # see the plan without touching anything
./bin/deploykit deploy             # run it for real
./bin/deploykit doctor             # full health report
./bin/deploykit status             # quick snapshot
./bin/deploykit rollback           # pick a previous release
```

Add `bin/` to your `PATH`, or symlink `bin/deploykit` into
`/usr/local/bin`, to run it as `deploykit` from anywhere.

## How a deploy actually runs

1. Load + validate `deploy.config.sh`
2. Preflight checks (required binaries, `.env` present, no deploy already
   running)
3. Check for local (uncommitted) changes in the repo
4. `git pull --ff-only`
5. Diff the old and new HEAD to classify what changed
6. Install backend deps only if `backend/package-lock.json` changed
7. Install frontend deps only if `frontend/package-lock.json` changed
8. Build the frontend only if anything under `frontend/` changed
9. Rsync the build to `WEBROOT`, snapshot it as a new release
10. Restart PM2 only if anything under `backend/` changed
11. Confirm PM2 reports the process `online`
12. Reload Nginx only if the template changed; otherwise just `nginx -t`
13. Retry-checked backend + frontend HTTP health checks
14. Report SSL days-remaining
15. Write the run to `logs/` and print a summary

If any step fails, the pipeline stops immediately — it does not proceed to
restart services on top of a half-finished state.

## Directory layout

```
deploykit/
├── bin/
│   └── deploykit
├── commands/
├── lib/
├── templates/
├── releases/
├── logs/
└── README.md
```

## Rollback model

Every frontend deploy snapshots `WEBROOT` into
`releases/<timestamp>/` and updates a `releases/current` symlink.
`deploykit rollback` lets you pick any prior release, rsyncs it back into
`WEBROOT`, restarts PM2, reloads Nginx, and re-runs health checks — so a
rollback is validated the same way a forward deploy is. Old releases beyond
`MAX_RELEASES` are pruned automatically.

## Explicit non-goals (for now)

This is a v1 built around a single Linux server. Deliberately **not**
included yet, to keep the core pipeline trustworthy before growing it:

- Unattended server bootstrap (`deploykit install`) — installing Node/PM2/
  Nginx/Certbot/UFW unattended is exactly the kind of thing that should be
  reviewed line-by-line the first time, not scripted blind.
- Docker / Kubernetes / blue-green deploys — different deployment model
  entirely; bolting it onto a PM2-based tool would compromise both.
- Live TUI dashboard (`deploykit monitor`) — nice to have, but `doctor` and
  `status` cover the same information without the added surface area.
- Multi-server / remote orchestration, plugin system, Slack/Discord
  notifications, automatic DB migrations.

## Screenshots

_TODO: add terminal captures of `deploykit doctor`, `deploykit deploy`, and
`deploykit rollback` here — a scanned README with visuals lands better than
one that's all text._

## Why Bash?

DeployKit intentionally targets single-server deployments.

It avoids introducing additional orchestration layers so developers can
understand and control every deployment step. Rather than replacing
standard Linux tools, it composes them into a consistent deployment
workflow.

## Inspired by

- Capistrano
- Mina
- Dokku
- PM2
- GitHub Actions

## Adapting DeployKit to other stacks

The defaults assume Express (backend) + Vite or CRA (frontend) with npm,
but nothing in `lib/` or `commands/` is actually npm/Vite-specific anymore.
Six config vars control the stack-dependent behavior — everything else
(PM2 lifecycle, Nginx validation, SSL checks, rollback, logging) is
already generic:

| Variable | Default | What it controls |
|---|---|---|
| `BUILD_OUTPUT_DIR` | `dist` | Folder rsynced to `WEBROOT` after a frontend build |
| `FRONTEND_BUILD_CMD` | `npm run build` | Command run inside `FRONTEND_DIR` |
| `BACKEND_INSTALL_CMD` | `npm ci` | Command run when the backend lockfile changes |
| `FRONTEND_INSTALL_CMD` | `npm ci` | Command run when the frontend lockfile changes |
| `BACKEND_LOCKFILE` | `package-lock.json` | Filename that triggers a backend install |
| `FRONTEND_LOCKFILE` | `package-lock.json` | Filename that triggers a frontend install |

Set these in `deploy.config.sh`; no code changes needed. Presets for
common stacks:

**Next.js (static export) frontend**
```bash
BUILD_OUTPUT_DIR=out
FRONTEND_BUILD_CMD="npm run build"
```
If you're using Next.js in server mode instead of static export, treat it
like a backend service (PM2-managed, proxied through Nginx) rather than
something deployed to `WEBROOT` — skip the frontend build/rsync steps and
add a second PM2 app entry in `ecosystem.config.cjs`.

**SvelteKit (static adapter)**
```bash
BUILD_OUTPUT_DIR=build   # or `public`, depending on your adapter config
```

**Vue / Nuxt (static generate)**
```bash
BUILD_OUTPUT_DIR=dist    # .output/public for Nuxt 3 generate
```

**pnpm or yarn instead of npm**
```bash
BACKEND_INSTALL_CMD="pnpm install --frozen-lockfile"
FRONTEND_INSTALL_CMD="pnpm install --frozen-lockfile"
BACKEND_LOCKFILE=pnpm-lock.yaml
FRONTEND_LOCKFILE=pnpm-lock.yaml
```

**Non-Express backend (Fastify, Koa, NestJS)**
No config vars needed — DeployKit only restarts a PM2 process and hits a
health endpoint, it doesn't care what's inside. Update `script` in
`templates/ecosystem.config.cjs` to point at your entry file (e.g.
NestJS's compiled `dist/main.js`), and set `BACKEND_HEALTH_PATH` if your
health route isn't `/health`.

**Backend-only or frontend-only projects**
Delete the branch you don't need directly in `commands/deploy.sh` (the
`NEEDS_FRONTEND_BUILD` or `NEEDS_BACKEND_RESTART` block), and drop the
unused `*_DIR` var from your config. The change-detection and health-check
logic in `lib/` don't assume both halves exist.

**What still assumes a single Linux server + PM2 + Nginx**
Swapping the frontend/backend tooling above is config-only. Swapping the
*deployment target* — e.g. containers instead of PM2, a CDN instead of
Nginx-served static files — is a bigger change, since `lib/pm2.sh`,
`lib/nginx.sh`, and the rollback symlink model in `lib/rollback.sh` are
all written against that assumption. That's tracked as a future direction
in Roadmap, not a config toggle.

## Roadmap

- `deploykit install` — guided, confirmable (not silent) server bootstrap
- `deploykit backup` — scheduled DB + `.env` backups
- Automatic rollback when post-deploy health checks fail
- GitHub Actions integration (trigger `deploykit deploy` on push to main)
- Multiple environments (staging/production via separate config files)
- `deploykit monitor` live dashboard
