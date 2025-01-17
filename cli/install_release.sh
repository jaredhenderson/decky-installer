#!/bin/bash
# To execute, run the below:
# curl -L https://github.com/jaredhenderson/decky-installer/raw/refs/heads/main/cli/install_release.sh | bash

# [ "$UID" -eq 0 ] || exec sudo "$0" "$@"

# check if JQ is installed
# if ! command -v jq &> /dev/null
# then
#     echo "JQ could not be found, please install it"
#     echo "Info on how to install it can be found at https://stedolan.github.io/jq/download/"
#     exit 1
# fi

# check if github.com is reachable
if ! curl -Is https://github.com | head -1 | grep 200 > /dev/null
then
    echo "Github appears to be unreachable, you may not be connected to the internet"
    exit 1
fi

echo "Installing Steam Deck Plugin Loader release..."

USER_DIR="/userdata/system"
HOMEBREW_FOLDER="${USER_DIR}/homebrew"
SERVICES_FOLDER="${USER_DIR}/services"
FLATPAK_FOLDER="/userdata/saves/flatpak/data"

# Create folder structure
rm -rf "${HOMEBREW_FOLDER}/services"
mkdir -p "${HOMEBREW_FOLDER}/services"
mkdir -p "${HOMEBREW_FOLDER}/plugins"

# if installed as flatpak, put .cef-enable-remote-debugging there
touch "${FLATPAK_FOLDER}/.var/app/com.valvesoftware.Steam/.steam/steam/.cef-enable-remote-debugging"

# Download latest release and install it
RELEASE=$(curl -s 'https://api.github.com/repos/SteamDeckHomebrew/decky-loader/releases' | jq -r "first(.[] | select(.prerelease == "false"))")
VERSION=$(jq -r '.tag_name' <<< ${RELEASE} )
DOWNLOADURL=$(jq -r '.assets[].browser_download_url | select(endswith("PluginLoader"))' <<< ${RELEASE})

printf "Installing version %s...\n" "${VERSION}"
curl -L $DOWNLOADURL --output ${HOMEBREW_FOLDER}/services/PluginLoader
chmod +x ${HOMEBREW_FOLDER}/services/PluginLoader

# echo "Check for SELinux presence and if it is present, set the correct permission on the binary file..."
# hash getenforce 2>/dev/null && getenforce | grep "Enforcing" >/dev/null && chcon -t bin_t ${HOMEBREW_FOLDER}/services/PluginLoader

echo $VERSION > ${HOMEBREW_FOLDER}/services/.loader.version

batocera-services stop plugin_loader 2> /dev/null
batocera-services disable plugin_loader 2> /dev/null

if [[ -f "${SERVICES_FOLDER}/plugin_loader" ]]; then
    printf "Back up existing service.\n"
    cp -f "${SERVICES_FOLDER}/plugin_loader" "${SERVICES_FOLDER}/plugin_loader_backup"
fi

curl -L https://raw.githubusercontent.com/jaredhenderson/decky-loader/main/dist/plugin_loader-release.sh  --output ${SERVICES_FOLDER}/plugin_loader_release

if [[ -f "${SERVICES_FOLDER}/plugin_loader_release" ]]; then
    printf "Grabbed latest release service.\n"
    # sed -i -e "s|\${SERVICES_FOLDER}|${SERVICES_FOLDER}|" "${SERVICES_FOLDER}/plugin_loader_release"
    cp -f "${SERVICES_FOLDER}/plugin_loader_release" "${SERVICES_FOLDER}/plugin_loader"
else
    printf "Could not curl latest release systemd service, using built-in service as a backup!\n"
    cp "${SERVICES_FOLDER}/plugin_loader_backup" "${SERVICES_FOLDER}/plugin_loader"
fi

mkdir -p ${SERVICES_FOLDER}/.decky_service_backups
cp ${SERVICES_FOLDER}/plugin_loader_backup ${SERVICES_FOLDER}/.decky_service_backups/plugin_loader_backup
rm ${SERVICES_FOLDER}/plugin_loader_backup ${SERVICES_FOLDER}/plugin_loader_release

batocera-services enable plugin_loader
batocera-services start plugin_loader
