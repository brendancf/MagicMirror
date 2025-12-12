Modules to install

`git clone https://github.com/KirAsh4/calendar_monthly`
`git clone https://github.com/kolbyjack/MMM-Wallpaper.git`
`git clone https://github.com/linuxtuxie/MMM-SunnyPortal.git`
`git clone https://github.com/Jopyth/MMM-Remote-Control`
`git clone https://github.com/ianperrin/MMM-ModuleScheduler.git`
`git clone https://github.com/BKeyport/MMM-Multimonth`

## Forked repositories to install

`git clone git@github.com:brendancf/MMM-Wallpaper.git`
`git clone git@github.com:brendancf/MMM-GoogleCalendar.git`
`git clone git@github.com:brendancf/MMM-GooglePhotos.git`
`git clone git@github.com:brendancf/MMM-GoogleTrafficTimes.git`
`git clone git@github.com:brendancf/MMM-Sonos.git`
`git clone git@github.com:brendancf/MMM-WyzeBridge.git`
`git clone git@github.com:brendancf/MMM-GoogleMapsTraffic.git`
`git clone git@github.com:brendancf/MMM-WeatherGraph.git`

Set up WyzeBridge
https://github.com/mrlt8/docker-wyze-bridge

Run Wyze bridge
`sudo docker compose -f wyze-bridge-docker-compose.yaml up -d`

Mac
`docker-compose -f wyze-bridge-docker-compose.yaml up -d`

# Display

1440 x 2560

## Manual Setup Files

- google credentials.json
- config.json
- wyzebridge docker compose

# Run Locally

`npm run start`

## Restart

pm2 restart mm

# Deployment

Production server: `192.168.1.200`

## Scripts

All scripts are in the `scripts/` directory. Before first use, create `scripts/.env`:

```bash
SERVER=brendancf@192.168.1.200
REMOTE_DIR=Documents/code/MagicMirror
```

### Deploy to Production

```bash
./scripts/deploy.sh
```

Deploys your code to the Raspberry Pi:

- Validates all changes are committed and pushed (main repo + modules)
- Pulls latest code on the server
- Installs dependencies
- Restarts MagicMirror via pm2

### Check for Upstream Updates

```bash
./scripts/update-from-upstream.sh          # Show status only
./scripts/update-from-upstream.sh --merge  # Merge upstream changes
```

Checks your forked repos for updates from upstream:

- Automatically adds the `upstream` remote if missing
- Shows how many commits behind/ahead you are
- With `--merge`, merges upstream into your local branch

### Other Scripts

```bash
./scripts/restart.sh        # Restart MagicMirror on server
./scripts/server-status.sh  # Check pm2 status on server
./scripts/fetch-logs.sh     # Fetch logs from server
```

## Manual Access

```bash
ssh brendancf@192.168.1.200
cd Documents/code/MagicMirror
pm2 restart mm
```
