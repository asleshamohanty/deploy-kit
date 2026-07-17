// Copy to your backend directory and adjust `script`/`env` as needed.
// DeployKit's pm2_restart_or_start() uses this if it's present.
module.exports = {
  apps: [
    {
      name: "my-app",
      script: "./dist/server.js", // or index.js — whatever your entry point is
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      max_restarts: 10,
      min_uptime: "10s",
      env: {
        NODE_ENV: "production",
      },
    },
  ],
};
