#!/usr/bin/env bash

set -euo pipefail

DOWNLOAD_URI=https://github.com/wakatime/xcode-wakatime/archive/master.tar.gz
PLUGINS_DIR="${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins"
XCODE_VERSION="$(xcrun xcodebuild -version | head -n1 | awk '{ print $2 }')"
PLIST_PLUGINS_KEY="DVTPlugInManagerNonApplePlugIns-Xcode-${XCODE_VERSION}"
BUNDLE_ID="WakaTime.WakaTime"
APP="/Applications/Xcode.app"

args="$@"

contains() {
  string="$1"
  if [[ -z ${2+x} ]]; then
    echo "";
  else
    substring="$2"
    if printf %s\\n "${string}" | grep -qF "${substring}"; then
      echo "1";
    else
      echo "";
    fi
  fi
}

if [[ $(contains "$args" "beta") ]]; then
  APP="/Applications/Xcode-beta.app"
fi

running=$(pgrep Xcode || true)
if [ "$running" != "" ]; then
  echo "Please quit Xcode then try running this script again."
  exit 1
fi

if [[ $(contains "$args" "copy") ]]; then
  echo "Copying Xcode.app to XcodeWithPlugins.app..."
  sudo cp -Rp "/Applications/Xcode.app" "/Applications/XcodeWithPlugins.app"
  APP="/Applications/XcodeWithPlugins.app"
fi

echo "Installing Alcatraz..."
curl -fsSL https://raw.github.com/alcatraz/Alcatraz/master/Scripts/install.sh | sh

echo "Installing WakaTime..."

# Remove WakaTime from Xcode's skipped plugins list if needed
TMP_FILE="$(mktemp -t ${BUNDLE_ID})"
if defaults read com.apple.dt.Xcode "$PLIST_PLUGINS_KEY" &> "$TMP_FILE"; then
  # We read the prefs successfully, delete WakaTime from the skipped list if needed
  /usr/libexec/PlistBuddy -c "delete skipped:$BUNDLE_ID" "$TMP_FILE" > /dev/null 2>&1 && {
    defaults write com.apple.dt.Xcode "$PLIST_PLUGINS_KEY" "$(cat "$TMP_FILE")"
    echo 'WakaTime was removed from Xcode'\''s skipped plugins list.' \
         'Next time you start Xcode select "Load Bundle" when prompted.'
  }
else
    # Could not read the prefs. Filter known warnings, and exit for any other.
    KNOWN_WARNING="The domain/default pair of \(.+, $PLIST_PLUGINS_KEY\) does not exist"

    # tr: For some mysterious reason, some `defaults` errors are outputed on two lines.
    # grep: -v returns 1 when output is empty (ie. we filtered the known warning)
    # so we exit on 0, which means an unknown error occured.
    tr -d '\n' < "$TMP_FILE" | egrep -v "$KNOWN_WARNING" && exit 1
fi
rm -f "$TMP_FILE"

# Download and install WakaTime
mkdir -p "${PLUGINS_DIR}"
curl -L $DOWNLOAD_URI | tar xvz -C "${PLUGINS_DIR}"

# Build WakaTime plugin
/usr/bin/xcodebuild clean build -project "$PLUGINS_DIR/xcode-wakatime-master/WakaTime.xcodeproj"
rm -r "$PLUGINS_DIR/xcode-wakatime-master"

echo "Make sure plugins have the latest Xcode compatibility UUIDs..."
UUIDS=$(defaults read $APP/Contents/Info.plist DVTPlugInCompatibilityUUID)
find ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins -name Info.plist -maxdepth 3 | xargs -I{} defaults write {} DVTPlugInCompatibilityUUIDs -array-add $UUIDS

echo "Finished installing WakaTime."
echo "************************************************"
echo "* Do you have a File -> WakaTime API Key menu in Xcode now?"
echo "* If not, run the full install script:"
echo "* curl -fsSL https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/install.sh | sh"
echo "************************************************"

exit 0
