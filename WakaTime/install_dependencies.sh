#!/bin/bash

#  install_dependencies.sh
#
#  :description: post-build script to install wakatime python package
#
#  :maintainer: WakaTime <support@wakatime.com>
#  :license: BSD, see LICENSE for more details.
#  :website: https://wakatime.com/

set -e
set -x

url="https://wakatime-cli.s3-us-west-2.amazonaws.com/mac-x86-64/wakatime-cli.zip"
if [ -d "$INSTALL_DIR" ]; then
    extract_to="$INSTALL_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
else
    extract_to="$HOME/Library/Application Support/Developer/Shared/Xcode/Plug-ins/WakaTime.xcplugin/Contents/Resources"
fi
zip_file="$extract_to/wakatime-cli.zip"
installed_package="$extract_to/wakatime-cli"

if [ -d "$installed_package" ]; then
    rm -rf "$installed_package"
fi

cd "$extract_to"

echo "Downloading wakatime package to $zip_file ..."
curl "$url" -o "$zip_file"

echo "Unzipping wakatime.zip to $installed_package ..."
unzip -q -o "$zip_file" || true

installed_binary="$installed_package/wakatime-cli"
chmod a+x "$installed_binary"

rm "$zip_file"

echo "Downloading wakatime cron script..."
url="https://wakatime-cli.s3-us-west-2.amazonaws.com/check_need_reinstall_plugin.py"
local_file="$extract_to/check_need_reinstall_plugin.py"
curl "$url" -o "$local_file"
chmod a+x "$local_file"

echo "Finished."

exit 0
