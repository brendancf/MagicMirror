Modules to install

`git clone git@github.com:brendancf/MMM-GoogleCalendar.git`
`git clone git@github.com:brendancf/MMM-GooglePhotos.git`
`git clone git@github.com:brendancf/MMM-GoogleTrafficTimes.git`
`git clone git@github.com:brendancf/MMM-Sonos.git`
`git clone git@github.com:brendancf/MMM-WyzeBridge.git`
`git clone git@github.com:brendancf/MMM-GoogleMapsTraffic.git`
`git clone https://github.com/KirAsh4/calendar_monthly`
`git clone https://github.com/kolbyjack/MMM-Wallpaper.git`
`git clone git@github.com:brendancf/MMM-Wallpaper.git`
`git clone https://github.com/linuxtuxie/MMM-SunnyPortal.git`
`git clone https://github.com/Jopyth/MMM-Remote-Control`
`git clone https://github.com/ianperrin/MMM-ModuleScheduler.git`
`git clone https://github.com/FlatPepsi17/MMM-WeatherGraph`

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

## Restart

pm2 restart mm
