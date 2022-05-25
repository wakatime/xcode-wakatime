#!/usr/bin/env bash

set -euo pipefail

PLUGINS_DIR="${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins"
ME="${USER}"

echo "Removing crontab checking for Xcode updates..."
sudo sed -i '' '/WakaTime/d' "/var/at/tabs/$ME"

# Delete WakaTime and Alcatraz plugins
echo "Deleting WakaTime and Alcatraz plugin bundles..."
rm -rf "${PLUGINS_DIR}/WakaTime.xcplugin"
rm -rf "${PLUGINS_DIR}/Alcatraz.xcplugin"

# Delete WakaTime config files from $HOME folder
echo "Deleting WakaTime config and log files..."
rm -rf $HOME/.wakatime*

echo "Deleting self-signed cert from default keychain..."
security delete-identity -c XcodeSigner2018

echo "Finished uninstalling WakaTime."
echo "Optionally, delete <code>/Applications/XcodeWithPlugins.app</code> if you installed with the copy argument."

exit 0
