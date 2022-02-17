#!/bin/bash

set -e

# password complexity prevents tizen from asking it
AUTHOR_CERT_PASSWORD="${AUTHOR_CERT_PASSWORD:-Abcd%1234}"
# any 2 letter code should work
AUTHOR_CERT_COUNTRY_CODE="${AUTHOR_CERT_COUNTRY_CODE:-XX}"
AUTHOR_CERT_CITY="${AUTHOR_CERT_CITY:-AnyCity}"
AUTHOR_CERT_ORG="${AUTHOR_CERT_ORG:-AnyCompany}"
AUTHOR_CERT_NAME="${AUTHOR_CERT_NAME:-Any Name}"
AUTHOR_CERT_EMAIL="${AUTHOR_CERT_EMAIL:-test@anycompany.com}"

TIZEN_SDK_DATA_PATH=$HOME/tizen-studio-data

indent() { sed 's/^/    /'; }
blue() { sed 's/^/\o033[0;34m/;s/$/\o033[0m/'; }
red() { sed 's/^/\o033[0;31m/;s/$/\o033[0m/'; }
darkgray() { sed 's/^/\o033[1;30m/;s/$/\o033[0m/'; }
indentdarkgray() { indent | darkgray; }
error() { echo $1 | red >&2; }

echo "Creating author certificate..." | blue
tizen certificate -a dev -p ${AUTHOR_CERT_PASSWORD:?} -c "${AUTHOR_CERT_COUNTRY_CODE:?}" -ct "${AUTHOR_CERT_CITY:?}" -o "${AUTHOR_CERT_ORG:?}" -n "${AUTHOR_CERT_NAME:?}" -e "${AUTHOR_CERT_EMAIL:?}" | indentdarkgray
if [ $? -ne 0 -o ! -f ${TIZEN_SDK_DATA_PATH:?}/keystore/author/author.p12 ]; then
    echo "ERROR: something went wrong creating author certificate" | red
    exit 1
fi

echo "Creating security profile..." | blue
tizen security-profiles add -n dev -a ${TIZEN_SDK_DATA_PATH:?}/keystore/author/author.p12 -p ${AUTHOR_CERT_PASSWORD:?} | indentdarkgray
if [ $? -ne 0 -o ! -f ${TIZEN_SDK_DATA_PATH:?}/profile/profiles.xml ]; then
    echo "ERROR: something went wrong creating security profile" | red
    exit 1
fi
sed -ie '/distributor="0"/ s/password="\([^"]*\)"/password="'${AUTHOR_CERT_PASSWORD:?}'"/' ${TIZEN_SDK_DATA_PATH:?}/profile/profiles.xml
sed -ie '/distributor="1"/ s/password="\([^"]*\)"/password="tizenpkcs12passfordsigner"/' ${TIZEN_SDK_DATA_PATH:?}/profile/profiles.xml

if [ -n "$SERVER_ADDRESS" ]; then
    echo "Setting server address $SERVER_ADDRESS..." | blue    
    sed -i  's/\("servers":\s*\)\[\],/\1["'"${SERVER_ADDRESS//\//\\/}"'"],/' ./www/config.json | indentdarkgray
    if [ $? -ne 0  ]; then
        echo "ERROR: something went wrong setting server address" | red
        exit 1
    fi
fi

echo "Build Jellyfin Web for tizen..." | blue
tizen build-web -e ".*" -e gulpfile.js -e README.md -e "node_modules/*" -e "jellyfin-web/*" -e "package*.json" -e "yarn.lock" | indentdarkgray
if [ $? -ne 0 -o ! -d ./.buildResult ]; then
    echo "ERROR: something went wrong building Jellyfin Web for tizen" | red
    exit 1
fi

echo "Build Jellyfin tizen package..." | blue
tizen package -t wgt -s dev -- .buildResult | indentdarkgray
if [ $? -ne 0 -o ! -f ./.buildResult/Jellyfin.wgt ]; then
    echo "ERROR: something went wrong building Jellyfin tizen package" | red
    exit 1
fi

if [ -n "${DEPLOY_IPS}" ]; then
    echo "Starting SDB server..." | blue
    sdb start-server | indentdarkgray
    if [ $? -ne 0  ]; then
        echo "ERROR: something went starting SDB server" | red
        exit 1
    fi
fi

for ip in ${DEPLOY_IPS//,/ }; do
    echo "Connecting to $ip..." | blue
    sdb connect $ip | indentdarkgray
    if [ $? -ne 0  ]; then
        echo "ERROR: something went wrong connecting to $ip" | red
        exit 1
    fi
    serial=$(sdb devices | awk  "/^$ip:/{print \$1}")
    if  [ ! -n "$serial" ]; then
        error "ERROR: could not connect to device with IP: $ip"
        continue
    fi
    echo "Checking Jellyfin app on device..." | blue
    appId=$(sdb -s $serial shell 0 applist | awk '/Jellyfin/{gsub(/[^0-9A-Za-z\.]/,"", $2) ;print $2}')
    if [ -n "$appId" ]; then
        echo "Detected Jellyfin app on device, uninstalling..." | blue
        tizen uninstall -s $serial -p $appId | indentdarkgray
        if [ $? -ne 0 -o -n "$(sdb -s $serial shell 0 applist | awk '/Jellyfin/{gsub(/[^0-9A-Za-z\.]/,"", $2) ;print $2}')" ]; then
            echo "ERROR: something went wrong uninstalling Jellyfin app" | red
            exit 1
        fi
    fi
    echo "Installing Jellyfin app on device..." | blue
    tizen install -s $serial -n .buildResult/Jellyfin.wgt | indentdarkgray
    if [ $? -ne 0 -o ! -n "$(sdb -s $serial shell 0 applist | awk '/Jellyfin/{gsub(/[^0-9A-Za-z\.]/,"", $2) ;print $2}')" ]; then
        echo "ERROR: something went wrong installing Jellyfin app" | red
        exit 1
    fi    
    echo "Disconnecting from $ip..." | blue
    sdb disconnect $serial | indentdarkgray
    if [ $? -ne 0  ]; then
        echo "ERROR: something went wrong disconnecting from $ip" | red
        exit 1
    fi
done
