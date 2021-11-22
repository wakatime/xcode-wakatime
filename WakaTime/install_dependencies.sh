#!/bin/bash

#  install_dependencies.sh
#
#  :description: post-build script to install wakatime-cli
#
#  :maintainer: WakaTime <support@wakatime.com>
#  :license: BSD, see LICENSE for more details.
#  :website: https://wakatime.com/

set -e
set -x

arch="amd64"
if [[ $(uname -m) == "aarch64" ]]; then
  arch="arm64"
fi

if [ -d "$INSTALL_DIR" ]; then
    extract_to="$INSTALL_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
else
    extract_to="$HOME/Library/Application Support/Developer/Shared/Xcode/Plug-ins/WakaTime.xcplugin/Contents/Resources"
fi

zip_file="$extract_to/wakatime-cli-darwin-${arch}.zip"
extracted_binary="$extract_to/wakatime-cli-darwin-${arch}"
installed_binary="$extract_to/wakatime-cli-darwin"
url="https://github.com/wakatime/wakatime-cli/releases/latest/download/wakatime-cli-darwin-${arch}.zip"

cd "$extract_to"

echo "Downloading wakatime-cli to $zip_file ..."
curl -L "$url" -o "$zip_file"

echo "Unzipping zip_file ..."
unzip -q -o "$zip_file" || true

mv "$extracted_binary" "$installed_binary"
chmod a+x "$installed_binary"

echo "Installed $installed_binary"

rm "$zip_file"

echo "Downloading wakatime script to check if updates needed..."
url="https://wakatime-cli.s3-us-west-2.amazonaws.com/check_need_reinstall_plugin.py"
local_file="$extract_to/check_need_reinstall_plugin.py"
curl "$url" -o "$local_file"
chmod a+x "$local_file"

echo "Finished installing wakatime-cli."

exit 0
