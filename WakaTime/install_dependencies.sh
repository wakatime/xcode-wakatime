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

extract_to="$HOME/.wakatime"

zip_file="$extract_to/wakatime-cli-darwin-${arch}.zip"
extracted_binary="$extract_to/wakatime-cli-darwin-${arch}"
symlink="$extract_to/wakatime-cli"
url="https://github.com/wakatime/wakatime-cli/releases/latest/download/wakatime-cli-darwin-${arch}.zip"

cd "$extract_to"

echo "Downloading wakatime-cli to $zip_file ..."
curl -L "$url" -o "$zip_file"

echo "Unzipping zip_file ..."
unzip -q -o "$zip_file" || true

chmod a+x "$extracted_binary"
ln -sfF "$extracted_binary" "$symlink"

echo "Installed $symlink"

rm "$zip_file"

# echo "Downloading wakatime script to check if updates needed..."
# url="https://wakatime-cli.s3-us-west-2.amazonaws.com/check_need_reinstall_plugin.py"
# local_file="$extract_to/check_need_reinstall_plugin.py"
# curl "$url" -o "$local_file"
# chmod a+x "$local_file"

echo "Finished installing wakatime-cli."

exit 0
