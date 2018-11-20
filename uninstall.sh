#!/usr/bin/env bash

set -euo pipefail

PLUGINS_DIR="${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins"

# Delete WakaTime and Alcatraz plugins
echo "Deleting WakaTime and Alcatraz plugin bundles..."
rm -rf "${PLUGINS_DIR}/WakaTime.xcplugin"
rm -rf "${PLUGINS_DIR}/Alcatraz.xcplugin"

# Delete WakaTime config files from $HOME folder
echo "Deleting WakaTime config and log files..."
rm "${HOME}/.wakatime.*"

echo "Deleting self-signed cert from default keychain..."
security delete-identity -c XcodeSigner2018

echo "Finished uninstalling WakaTime."

exit 0
