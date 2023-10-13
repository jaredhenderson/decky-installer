#!/bin/sh

[ "$UID" -eq 0 ] || exec sudo "$0" "$@"

# check if JQ is installed
if ! command -v jq &> /dev/null
then
    echo "JQ could not be found, please install it"
    echo "Info on how to install it can be found at https://stedolan.github.io/jq/download/"
    exit 1
fi

# check if github.com is reachable
if ! curl -Is https://github.com | head -1 | grep 200 > /dev/null
then
    echo "Github appears to be unreachable, you may not be connected to the internet"
    exit 1
fi

echo "Installing Steam Deck Plugin Loader pre-release..."

USER_DIR="$(getent passwd $SUDO_USER | cut -d: -f6)"
HOMEBREW_FOLDER="${USER_DIR}/homebrew"

# Create folder structure
rm -rf "${HOMEBREW_FOLDER}/services"
sudo -u $SUDO_USER mkdir -p "${HOMEBREW_FOLDER}/services"
sudo -u $SUDO_USER mkdir -p "${HOMEBREW_FOLDER}/plugins"
sudo -u $SUDO_USER touch "${USER_DIR}/.steam/steam/.cef-enable-remote-debugging"
# if installed as flatpak, put .cef-enable-remote-debugging there
[ -d "${USER_DIR}/.var/app/com.valvesoftware.Steam/data/Steam/" ] && sudo -u $SUDO_USER touch "${USER_DIR}/.var/app/com.valvesoftware.Steam/data/Steam/.cef-enable-remote-debugging"

# Download latest release and install it
RELEASE=$(curl -s 'https://api.github.com/repos/SteamDeckHomebrew/decky-loader/releases' | jq -r "first(.[] | select(.prerelease == "true"))")
VERSION=$(jq -r '.tag_name' <<< ${RELEASE} )
DOWNLOADURL=$(jq -r '.assets[].browser_download_url | select(endswith("PluginLoader"))' <<< ${RELEASE})

printf "Installing version %s...\n" "${VERSION}"
curl -L $DOWNLOADURL --output ${HOMEBREW_FOLDER}/services/PluginLoader
chmod +x ${HOMEBREW_FOLDER}/services/PluginLoader

echo "Check for SELinux presence and if it is present, set the correct permission on the binary file..."
hash getenforce 2>/dev/null && getenforce | grep "Enforcing" >/dev/null && chcon -t bin_t ${HOMEBREW_FOLDER}/services/PluginLoader

echo $VERSION > ${HOMEBREW_FOLDER}/services/.loader.version

systemctl --user stop plugin_loader 2> /dev/null
systemctl --user disable plugin_loader 2> /dev/null

systemctl stop plugin_loader 2> /dev/null
systemctl disable plugin_loader 2> /dev/null

curl -L https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/main/dist/plugin_loader-prerelease.service  --output ${HOMEBREW_FOLDER}/services/plugin_loader-prerelease.service

cat > "${HOMEBREW_FOLDER}/services/plugin_loader-backup.service" <<- EOM
[Unit]
Description=SteamDeck Plugin Loader
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
Restart=always
ExecStart=${HOMEBREW_FOLDER}/services/PluginLoader
WorkingDirectory=${HOMEBREW_FOLDER}/services
KillSignal=SIGKILL
Environment=PLUGIN_PATH=${HOMEBREW_FOLDER}/plugins
Environment=LOG_LEVEL=DEBUG
[Install]
WantedBy=multi-user.target
EOM

if [[ -f "${HOMEBREW_FOLDER}/services/plugin_loader-prerelease.service" ]]; then
    printf "Grabbed latest prerelease service.\n"
    sed -i -e "s|\${HOMEBREW_FOLDER}|${HOMEBREW_FOLDER}|" "${HOMEBREW_FOLDER}/services/plugin_loader-prerelease.service"
    cp -f "${HOMEBREW_FOLDER}/services/plugin_loader-prerelease.service" "/etc/systemd/system/plugin_loader.service"
else
    printf "Could not curl latest prerelease systemd service, using built-in service as a backup!\n"
    rm -f "/etc/systemd/system/plugin_loader.service"
    cp "${HOMEBREW_FOLDER}/services/plugin_loader-backup.service" "/etc/systemd/system/plugin_loader.service"
fi

mkdir -p ${HOMEBREW_FOLDER}/services/.systemd
cp ${HOMEBREW_FOLDER}/services/plugin_loader-prerelease.service ${HOMEBREW_FOLDER}/services/.systemd/plugin_loader-prerelease.service
cp ${HOMEBREW_FOLDER}/services/plugin_loader-backup.service ${HOMEBREW_FOLDER}/services/.systemd/plugin_loader-backup.service
rm ${HOMEBREW_FOLDER}/services/plugin_loader-backup.service ${HOMEBREW_FOLDER}/services/plugin_loader-prerelease.service

systemctl daemon-reload
systemctl start plugin_loader
systemctl enable plugin_loader
