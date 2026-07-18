#!/usr/bin/env bash
# Copy this to deploy.config.sh in your project root (or wherever you run
# `deploykit` from) and fill in your values. DeployKit loads this file
# automatically from $PWD, or from $DEPLOYKIT_CONFIG if set.
# shellcheck disable=SC2034

PROJECT_NAME=my-app

# Root of your git checkout on the server
PROJECT_DIR=/home/ubuntu/my-app

# Optional — auto-derived from PROJECT_DIR if omitted
BACKEND_DIR=$PROJECT_DIR/backend
FRONTEND_DIR=$PROJECT_DIR/frontend

# Where the built frontend gets rsynced to (Nginx serves from here)
WEBROOT=/var/www/my-app

DOMAIN=myapp.com

# PM2 process name (must match ecosystem.config.cjs if you use one)
PM2_APP=my-app

BACKEND_PORT=4000
BACKEND_HEALTH_PATH=/health
FRONTEND_HEALTH_PATH=/

NODE_VERSION=22

# How many old releases to keep for rollback
MAX_RELEASES=10

# --- Stack adaptation (defaults below assume Express + Vite/CRA React) ---
# Change these to point DeployKit at a different frontend/backend stack.
# See README "Adapting DeployKit to other stacks" for common presets.
BUILD_OUTPUT_DIR=dist
FRONTEND_BUILD_CMD="npm run build"
BACKEND_INSTALL_CMD="npm ci"
FRONTEND_INSTALL_CMD="npm ci"
BACKEND_LOCKFILE=package-lock.json
FRONTEND_LOCKFILE=package-lock.json
