# DeployKit — Usage Guide for Different Stacks

This is a practical, step-by-step guide to actually running DeployKit
against a real project. It covers the stack DeployKit assumes by default
(Express + React) and what to change for other common combinations,
including Python backends (FastAPI/Flask), which need real adaptation,
not just a config tweak.

If you just want the reference table of every config variable, see the
main `README.md`. This doc is the "I have a project, walk me through it"
version.

---

## 0. The one thing every stack has in common

No matter what's inside `backend/` or `frontend/`, DeployKit only ever
does three things to your app:

1. Runs an **install command** and a **build command** in each directory
   (only when their lockfile changes)
2. Tells **PM2** to start/restart one process for your backend
3. Tells **Nginx** to serve a folder of static files for your frontend

Everything else — health checks, SSL, logging, rollback — doesn't care
what language either half is written in. So adapting DeployKit to a new
stack is really just answering: *what installs it, what builds it, and
what command starts it?*

---

## 1. One-time server setup (do this once, regardless of stack)

SSH into your server and install the tools DeployKit expects to find:

```bash
# Node.js (needed even for Python backends — PM2 itself runs on Node)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# PM2 (the process manager DeployKit drives)
sudo npm install -g pm2
pm2 startup   # follow the printed instructions to enable on-boot restart

# Nginx + Certbot (reverse proxy + free SSL)
sudo apt-get install -y nginx certbot python3-certbot-nginx

# git, rsync (DeployKit uses both)
sudo apt-get install -y git rsync
```

Then clone your project and DeployKit itself onto the server:

```bash
git clone <your-project-repo-url> /home/ubuntu/my-app
git clone <deploykit-repo-url> /home/ubuntu/deploykit
```

Copy the config template and fill it in:

```bash
cd /home/ubuntu/my-app
cp /home/ubuntu/deploykit/templates/deploy.config.example.sh deploy.config.sh
nano deploy.config.sh
```

From here, what you fill in depends on your stack. Pick your case below.

---

## 2. Case A — Express backend + React frontend (fully native, no changes)

This is what DeployKit assumes by default. If your project looks like:

```
my-app/
├── backend/     (Express, has package.json + package-lock.json)
└── frontend/    (Vite or CRA React, has package.json + package-lock.json)
```

Your `deploy.config.sh` needs almost nothing beyond the basics:

```bash
PROJECT_NAME=my-app
PROJECT_DIR=/home/ubuntu/my-app
PM2_APP=my-app
DOMAIN=myapp.com
BACKEND_PORT=4000
```

Copy the PM2 ecosystem template and point it at your entry file:

```bash
cp /home/ubuntu/deploykit/templates/ecosystem.config.cjs /home/ubuntu/my-app/backend/
nano /home/ubuntu/my-app/backend/ecosystem.config.cjs
# change `script: "./dist/server.js"` to wherever your Express app starts,
# e.g. "./index.js" or "./src/server.js"
```

Make sure your Express app has a health route DeployKit can hit:

```js
app.get('/health', (req, res) => res.sendStatus(200));
```

Set up Nginx once, using the template as a starting point:

```bash
sudo cp /home/ubuntu/deploykit/templates/nginx.conf /etc/nginx/sites-available/my-app
sudo nano /etc/nginx/sites-available/my-app
# replace __DOMAIN__, __WEBROOT__, __BACKEND_PORT__ with real values
sudo ln -s /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d myapp.com
```

Then deploy:

```bash
cd /home/ubuntu/my-app
/home/ubuntu/deploykit/bin/deploykit deploy --dry-run   # sanity check first
/home/ubuntu/deploykit/bin/deploykit deploy              # for real
```

That's the whole flow for the native case. Everything below is a diff
against this.

---

## 3. Case B — a different Node backend (Fastify, Koa, NestJS)

No config changes needed at all — DeployKit only restarts a PM2 process
and hits a health URL, it doesn't know or care what's inside.

**Only touch two things:**

1. `ecosystem.config.cjs` — point `script` at your real entry file.
   NestJS example (compiled output):
   ```js
   module.exports = {
     apps: [{
       name: "my-app",
       script: "./dist/main.js",
       env: { NODE_ENV: "production" },
     }],
   };
   ```
2. `BACKEND_HEALTH_PATH` in `deploy.config.sh`, if your health route isn't
   `/health`.

Everything else (install command, lockfile detection) stays `npm ci` /
`package-lock.json` since it's still a Node project.

---

## 4. Case C — a different frontend framework

Same idea: only the **build output location** and **build command**
change. Set these in `deploy.config.sh`:

**Next.js (static export)**
```bash
BUILD_OUTPUT_DIR=out
FRONTEND_BUILD_CMD="npm run build"
```
If Next.js is running in server mode (not static export), it isn't a
"frontend served as static files" anymore — treat it like a second
backend: give it its own PM2 entry and skip the rsync-to-webroot step.

**SvelteKit (static adapter)**
```bash
BUILD_OUTPUT_DIR=build
```

**Vue / Nuxt (static generate)**
```bash
BUILD_OUTPUT_DIR=dist        # or .output/public for Nuxt 3 generate
```

**Using pnpm or yarn instead of npm (either half)**
```bash
BACKEND_INSTALL_CMD="pnpm install --frozen-lockfile"
FRONTEND_INSTALL_CMD="pnpm install --frozen-lockfile"
BACKEND_LOCKFILE=pnpm-lock.yaml
FRONTEND_LOCKFILE=pnpm-lock.yaml
```

---

## 5. Case D — Python backend (FastAPI or Flask) — this one needs real changes

This is the important case, because Python isn't just "a different Node
framework" — PM2's default assumptions (npm, package.json) don't apply.
Here's exactly what to change.

### 5.1 Install Python tooling on the server

```bash
sudo apt-get install -y python3 python3-venv python3-pip
```

### 5.2 Set up a virtual environment in your backend folder

```bash
cd /home/ubuntu/my-app/backend
python3 -m venv venv
venv/bin/pip install -r requirements.txt
venv/bin/pip install uvicorn   # if not already in requirements.txt (FastAPI)
# or: venv/bin/pip install gunicorn   (Flask)
```

### 5.3 Config changes — swap the Node-shaped defaults for Python ones

```bash
# deploy.config.sh
BACKEND_INSTALL_CMD="venv/bin/pip install -r requirements.txt"
BACKEND_LOCKFILE=requirements.txt   # triggers install when this file changes
```

`FRONTEND_*` vars stay as-is if your frontend is still React/Vite — this
only affects the backend half.

### 5.4 The critical part: write a Python-aware `ecosystem.config.cjs`

**Never rely on DeployKit's fallback start command for Python** — it
runs `npm start`, which doesn't exist in a Python project. Always ship a
custom ecosystem file. PM2 supports any interpreter, not just Node:

**FastAPI (via uvicorn):**
```js
module.exports = {
  apps: [{
    name: "my-app",
    script: "venv/bin/uvicorn",
    args: "main:app --host 0.0.0.0 --port 4000",
    interpreter: "none",   // tells PM2 "run this binary directly"
    env: { PYTHONUNBUFFERED: "1" },
  }],
};
```

**Flask (via gunicorn):**
```js
module.exports = {
  apps: [{
    name: "my-app",
    script: "venv/bin/gunicorn",
    args: "-w 2 -b 0.0.0.0:4000 app:app",
    interpreter: "none",
    env: { PYTHONUNBUFFERED: "1" },
  }],
};
```

Put this file at `backend/ecosystem.config.cjs` in your project (same
location as the Node case) — `lib/pm2.sh` looks for it automatically.

### 5.5 Health route

FastAPI:
```python
@app.get("/health")
def health():
    return {"status": "ok"}
```

Flask:
```python
@app.route("/health")
def health():
    return "ok", 200
```

### 5.6 Everything else is unchanged

Nginx setup, SSL, frontend deploy, rollback, logging — all identical to
Case A. The only things Python touches are: install command, lockfile
name, and the ecosystem file's `script`/`args`/`interpreter`.

---

## 6. Backend-only or frontend-only projects

If there's no frontend to build (e.g. a pure API), or no backend (e.g. a
static site with no server component):

- Remove the block you don't need in `commands/deploy.sh` — either the
  `NEEDS_FRONTEND_BUILD` section or the `NEEDS_BACKEND_RESTART` section.
- Drop the unused `*_DIR` variable from your config.
- Skip the Nginx `proxy_pass` block in the template if there's no
  backend to route to.

The change-detection and health-check logic in `lib/` don't assume both
halves exist — they only act on the flags that get set.

---

## 7. Full worked example: FastAPI + React

Putting it all together — a project shaped like:

```
my-app/
├── backend/          FastAPI, requirements.txt
└── frontend/         Vite React, package-lock.json
```

`deploy.config.sh`:
```bash
PROJECT_NAME=my-app
PROJECT_DIR=/home/ubuntu/my-app
PM2_APP=my-app
DOMAIN=myapp.com
BACKEND_PORT=4000
BACKEND_HEALTH_PATH=/health

BACKEND_INSTALL_CMD="venv/bin/pip install -r requirements.txt"
BACKEND_LOCKFILE=requirements.txt

# frontend stays default — Vite output, npm, dist/
```

`backend/ecosystem.config.cjs`:
```js
module.exports = {
  apps: [{
    name: "my-app",
    script: "venv/bin/uvicorn",
    args: "main:app --host 0.0.0.0 --port 4000",
    interpreter: "none",
  }],
};
```

Then:
```bash
cd /home/ubuntu/my-app
python3 -m venv backend/venv
backend/venv/bin/pip install -r backend/requirements.txt

/home/ubuntu/deploykit/bin/deploykit deploy --dry-run
/home/ubuntu/deploykit/bin/deploykit deploy
/home/ubuntu/deploykit/bin/deploykit doctor    # confirm everything's green
```

---

## 8. Quick troubleshooting

| Symptom | Likely cause |
|---|---|
| `pm2 start` fails with "npm: command not found" for a Python app | You skipped the custom `ecosystem.config.cjs` — the fallback assumes Node |
| Backend restarts but health check fails | `BACKEND_HEALTH_PATH` doesn't match a real route, or the app isn't listening on `BACKEND_PORT` |
| Frontend builds but doesn't show up on the site | `BUILD_OUTPUT_DIR` doesn't match what your build tool actually outputs — check the real folder name after running the build manually once |
| `Nginx config test failed` | Check the placeholders (`__DOMAIN__`, `__WEBROOT__`, `__BACKEND_PORT__`) got replaced with real values in `/etc/nginx/sites-available/my-app` |
| Install step never runs on a change | `BACKEND_LOCKFILE`/`FRONTEND_LOCKFILE` doesn't match your actual lockfile filename |

For anything not covered here, `deploykit doctor` and `deploykit logs`
are the first two commands to reach for — they're designed to surface
exactly this kind of mismatch.