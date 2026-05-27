# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MagicMirror² is a modular smart mirror platform. This is a personal fork running on a Raspberry Pi (`magic-mirror`, Tailscale) with several third-party modules installed.

## Common Commands

```bash
# Run locally (development)
npm run start           # Start with Electron
npm run start:dev       # Start in dev mode
npm run server          # Server-only mode (no Electron)

# Testing
npm test                # Run all tests
npm run test:unit       # Unit tests only
npm run test:e2e        # E2E tests only (Playwright)
npm run test:electron   # Electron-specific tests

# Linting
npm run test:prettier   # Check formatting
npm run test:js         # ESLint check
npm run test:css        # Stylelint check
npm run lint:prettier   # Fix formatting
npm run lint:js         # Fix JS issues
npm run lint:css        # Fix CSS issues

# Config validation
npm run config:check    # Validate config.js syntax
```

## Architecture

### Core Server (`js/app.js`, `js/server.js`)

- Express server with Socket.IO for real-time module communication
- Loads config from `config/config.js` (supports environment variable substitution via `.template` files)
- Modules communicate via socket notifications between client and node_helper

### Module System

Two-part architecture for each module:

1. **Frontend module** (`moduleName.js`) - Runs in browser, extends `Module` class from `js/module.js`

   - `getDom()` returns DOM to render
   - `getTemplate()` + `getTemplateData()` for Nunjucks templates (`.njk`)
   - `sendSocketNotification()` / `socketNotificationReceived()` for server communication

2. **Backend node_helper** (`node_helper.js`) - Runs on server, extends `NodeHelper` from `js/node_helper.js`
   - `start()` called on server startup
   - `socketNotificationReceived()` handles client messages
   - `sendSocketNotification()` sends data back to client

### Default Modules (`modules/default/`)

Built-in: alert, calendar, clock, compliments, helloworld, newsfeed, updatenotification, weather

### Installed Third-Party Modules

Located in `modules/`:

- MMM-GoogleCalendar, MMM-GooglePhotos, MMM-GoogleTrafficTimes
- MMM-Sonos, MMM-WyzeBridge, MMM-Wallpaper
- MMM-ModuleScheduler, MMM-Multimonth, MMM-Remote-Control
- MMM-SunnyPortal, MMM-WeatherGraph, calendar_monthly

## Git Repository Structure

**Important**: This project uses nested independent git repositories (not submodules):

- The root `MagicMirror-Brendan/` folder is one git repo
- Each third-party module in `modules/MMM-*` is its own separate git repo
- These are independent repos that happen to be nested, not git submodules

When committing changes:

1. Commit module changes within that module's directory: `cd modules/MMM-GoogleCalendar && git add . && git commit`
2. Commit MagicMirror core changes from the root directory
3. Each repo has its own remote and must be pushed separately

## Configuration

- Main config: `config/config.js` (create from `config/config.js.sample`)
- Modules array defines which modules load and their positions
- Module positions: `top_bar`, `top_left`, `top_center`, `top_right`, `upper_third`, `middle_center`, `lower_third`, `bottom_left`, `bottom_center`, `bottom_right`, `bottom_bar`, `fullscreen_above`, `fullscreen_below`

## Deployment

Production server: `magic-mirror` (Tailscale hostname, `100.96.37.30`, Node.js v20.19.1)

### Deploy Script

```bash
# From local machine - pulls git changes on server, installs deps, restarts
./scripts/deploy.sh
```

The deploy script:

1. Checks for uncommitted/unpushed changes locally (fails if any)
2. Runs `git pull` on server for main repo and all module repos
3. Runs `npm install` for main repo and modules with package.json
4. Restarts via `pm2 restart mm`

Configuration is in `scripts/.env` (gitignored). See `scripts/.env.sample` for template.

### Manual Server Access

```bash
ssh brendancf@magic-mirror
cd Documents/code/MagicMirror
pm2 restart mm
pm2 logs mm          # View logs
```

## Known Issues & Workarounds

### MMM-Remote-Control uuid ESM Issue

**Problem**: MMM-Remote-Control v3.3.0 uses `uuid@13` which is ESM-only. Electron's bundled Node.js doesn't support ESM `require()`, causing MagicMirror to fail to start.

**Workaround applied on server**:

```bash
cd modules/MMM-Remote-Control && npm install uuid@9
```

**Note**: This workaround gets overwritten when running `npm install` in that module. If MagicMirror fails to start after a deploy with an `ERR_REQUIRE_ESM` error mentioning uuid, re-run the workaround above.

**Permanent fix options**:

1. Wait for MMM-Remote-Control to fix the issue upstream
2. Fork MMM-Remote-Control and pin uuid@9 in package.json

### MMM-Sonos Git Identity

The server's MMM-Sonos repo may fail `git pull` if it needs to merge (git identity not configured). If this happens:

```bash
ssh brendancf@magic-mirror
cd Documents/code/MagicMirror/modules/MMM-Sonos
git config user.email "your@email.com"
git config user.name "Your Name"
git pull
```

## Testing Structure

Jest with three test projects:

- `tests/unit/` - Unit tests for utilities and classes
- `tests/e2e/` - End-to-end tests using Playwright
- `tests/electron/` - Electron-specific integration tests
- `tests/configs/` - Test configuration files
