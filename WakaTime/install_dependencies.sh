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

url="https://codeload.github.com/wakatime/wakatime/zip/master"
if [ -d "$INSTALL_DIR" ]; then
    extract_to="$INSTALL_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
else
    extract_to="$HOME/Library/Application Support/Developer/Shared/Xcode/Plug-ins/WakaTime.xcplugin/Contents/Resources"
fi
zip_file="$extract_to/wakatime.zip"
installed_package="$extract_to/wakatime-master"

if [ -d "$installed_package" ]; then
    rm -rf "$installed_package"
fi

cd "$extract_to"

echo "Downloading wakatime package to $zip_file ..."
curl "$url" -o "$zip_file"

echo "Unzipping wakatime.zip to $installed_package ..."
unzip -o "$zip_file"

rm "$zip_file"

echo "Making sure plugins have the latest Xcode compatibility UUIDs..."
find ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins -name Info.plist -maxdepth 3 | xargs -I{} defaults write {} DVTPlugInCompatibilityUUIDs -array-add `defaults read /Applications/Xcode.app/Contents/Info.plist DVTPlugInCompatibilityUUID`

echo "Finished."
