# Jellyfin Tizen Deploy via Docker

This is a repo to build Jellyfin for a Samsung TV with Tizen OS and install it automatically.

## Prepare

The Samsung TV needs to be in developer mode and set the IP of the host where you run this.

```shell
git clone https://github.com/spali/jellyfin-tizen-deploy
cd jellyfin-tizen-deploy
```

## Deploy

The Samsung TV's needs to be ON before execution below.
It's not included, but if you script the below commands, you can use etherwake or similar Wake on LAN tools to wake your Samsung TV's.

```shell
# optional: will preset the jellyfin server in the app.
SERVER_ADDRESS=https://jellyfin.example.org
# optional: comma separated list of Samsung TV ips.
DEPLOY_IPS=192.168.0.5
# build the image, only required to update jellyfin-web or jellyfin-tizen
docker build \
  --build-arg JELLYFIN_WEB_IMAGE_TAG=10.8.0-alpha5 \
  --pull --rm -f Dockerfile -t jellyfin-tizen-deploy:latest .
# build the app and deploy to the TV
docker run --rm -it \
  -e SERVER_ADDRESS=$SERVER_ADDRESS \
  -e DEPLOY_IPS=$DEPLOY_IPS \
  jellyfin-tizen-deploy:latest
```

## Advanced
Check the `Dockerfile` for possible build arguments to customize.
